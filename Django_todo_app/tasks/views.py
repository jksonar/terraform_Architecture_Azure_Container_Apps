from datetime import date

from django.contrib.auth.decorators import login_required
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.models import User
from django.contrib import messages
from django.core.exceptions import PermissionDenied
from django.db import connection
from django.db.models import Count, Q
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse_lazy
from django.views import View
from django.views.decorators.http import require_POST
from django.views.generic import (
    ListView, DetailView, CreateView, UpdateView, DeleteView
)


def health(request):
    try:
        connection.ensure_connection()
        return JsonResponse({'status': 'ok'})
    except Exception:
        return JsonResponse({'status': 'error'}, status=503)

from accounts.models import Department, UserProfile
from .models import TaskList, Task, TaskStatusHistory
from .forms import TaskListForm, TaskForm, SubTaskForm, TaskStatusForm, TaskFilterForm


# ---------------------------------------------------------------------------
# Mixins
# ---------------------------------------------------------------------------

class OwnerTaskListMixin(LoginRequiredMixin):
    model = TaskList

    def get_queryset(self):
        return TaskList.objects.filter(owner=self.request.user)


class RoleRequiredMixin(LoginRequiredMixin):
    allowed_roles = []

    def dispatch(self, request, *args, **kwargs):
        if not request.user.is_authenticated:
            return self.handle_no_permission()
        try:
            role = request.user.profile.role
        except UserProfile.DoesNotExist:
            raise PermissionDenied
        if self.allowed_roles and role not in self.allowed_roles:
            raise PermissionDenied
        return super().dispatch(request, *args, **kwargs)


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

ROLE_DASHBOARD_TEMPLATES = {
    UserProfile.ROLE_SENIOR_MANAGER: 'tasks/dashboard_senior_manager.html',
    UserProfile.ROLE_MANAGER: 'tasks/dashboard_manager.html',
    UserProfile.ROLE_TEAM_LEAD: 'tasks/dashboard_team_lead.html',
    UserProfile.ROLE_EMPLOYEE: 'tasks/dashboard_employee.html',
}


class DashboardView(LoginRequiredMixin, View):

    def get(self, request):
        profile = get_object_or_404(UserProfile, user=request.user)
        template = ROLE_DASHBOARD_TEMPLATES.get(
            profile.role, 'tasks/dashboard_employee.html'
        )
        ctx = self._build_context(profile)
        return render(request, template, ctx)

    def _build_context(self, profile):
        builders = {
            UserProfile.ROLE_SENIOR_MANAGER: self._senior_manager_context,
            UserProfile.ROLE_MANAGER: self._manager_context,
            UserProfile.ROLE_TEAM_LEAD: self._team_lead_context,
            UserProfile.ROLE_EMPLOYEE: self._employee_context,
        }
        builder = builders.get(profile.role, self._employee_context)
        return builder(profile)

    def _senior_manager_context(self, profile):
        today = date.today()
        departments = Department.objects.annotate(
            dept_total=Count('tasks', filter=Q(tasks__parent__isnull=True)),
            dept_completed=Count(
                'tasks',
                filter=Q(tasks__parent__isnull=True, tasks__status=Task.Status.COMPLETED)
            ),
            dept_pending=Count(
                'tasks',
                filter=Q(tasks__parent__isnull=True, tasks__status=Task.Status.PENDING)
            ),
            dept_overdue=Count(
                'tasks',
                filter=Q(
                    tasks__parent__isnull=True,
                    tasks__due_date__lt=today,
                    tasks__status__in=[Task.Status.PENDING, Task.Status.IN_PROGRESS],
                )
            ),
        ).order_by('name')

        employee_performance = User.objects.annotate(
            completed=Count(
                'assigned_tasks',
                filter=Q(
                    assigned_tasks__status=Task.Status.COMPLETED,
                    assigned_tasks__parent__isnull=True,
                )
            ),
            total=Count(
                'assigned_tasks',
                filter=Q(assigned_tasks__parent__isnull=True)
            ),
        ).filter(total__gt=0).order_by('-completed')[:10]

        root_tasks = Task.objects.filter(parent__isnull=True)
        return {
            'total_departments': Department.objects.count(),
            'total_employees': UserProfile.objects.count(),
            'pending_tasks': root_tasks.filter(status=Task.Status.PENDING).count(),
            'in_progress_tasks': root_tasks.filter(status=Task.Status.IN_PROGRESS).count(),
            'completed_tasks': root_tasks.filter(status=Task.Status.COMPLETED).count(),
            'overdue_tasks': root_tasks.filter(
                due_date__lt=today,
                status__in=[Task.Status.PENDING, Task.Status.IN_PROGRESS],
            ).count(),
            'departments': departments,
            'employee_performance': employee_performance,
        }

    def _manager_context(self, profile):
        dept_tasks = Task.objects.filter(
            department=profile.department, parent__isnull=True
        )
        subordinates = profile.get_all_subordinates()
        return {
            'team_members': UserProfile.objects.filter(
                pk__in=[p.pk for p in subordinates]
            ).select_related('user'),
            'assigned_tasks_count': dept_tasks.filter(
                status__in=[Task.Status.PENDING, Task.Status.IN_PROGRESS]
            ).count(),
            'completed_tasks': dept_tasks.filter(status=Task.Status.COMPLETED).count(),
            'pending_tasks': dept_tasks.filter(status=Task.Status.PENDING).count(),
            'recent_tasks': dept_tasks.order_by('-created_at')[:10],
            'department': profile.department,
        }

    def _team_lead_context(self, profile):
        subordinate_ids = [p.user_id for p in profile.get_all_subordinates()]
        team_tasks = Task.objects.filter(
            assigned_to_id__in=subordinate_ids, parent__isnull=True
        )
        return {
            'team_tasks_total': team_tasks.count(),
            'completed': team_tasks.filter(status=Task.Status.COMPLETED).count(),
            'pending': team_tasks.filter(status=Task.Status.PENDING).count(),
            'in_progress': team_tasks.filter(status=Task.Status.IN_PROGRESS).count(),
            'not_completed': team_tasks.filter(status=Task.Status.NOT_COMPLETED).count(),
            'recent_tasks': team_tasks.order_by('-created_at')[:10],
        }

    def _employee_context(self, profile):
        today = date.today()
        my_tasks = Task.objects.filter(
            assigned_to=profile.user, parent__isnull=True
        )
        return {
            'total': my_tasks.count(),
            'due_today': my_tasks.filter(due_date=today).count(),
            'pending': my_tasks.filter(status=Task.Status.PENDING).count(),
            'in_progress': my_tasks.filter(status=Task.Status.IN_PROGRESS).count(),
            'completed': my_tasks.filter(status=Task.Status.COMPLETED).count(),
            'not_completed': my_tasks.filter(status=Task.Status.NOT_COMPLETED).count(),
            'tasks': my_tasks.order_by('-priority', 'due_date'),
            'today': today,
            'status_choices': Task.Status.choices,
        }


# ---------------------------------------------------------------------------
# Role-scoped Task List
# ---------------------------------------------------------------------------

def _scope_tasks_by_role(qs, profile):
    """Filter a Task queryset to what this role is allowed to see."""
    role = profile.role
    if role == UserProfile.ROLE_SENIOR_MANAGER:
        return qs
    elif role == UserProfile.ROLE_MANAGER:
        return qs.filter(department=profile.department)
    elif role == UserProfile.ROLE_TEAM_LEAD:
        sub_ids = [p.user_id for p in profile.get_all_subordinates()]
        return qs.filter(
            Q(assigned_to_id__in=sub_ids) | Q(assigned_to=profile.user)
        )
    else:
        return qs.filter(assigned_to=profile.user)


class TaskListView(LoginRequiredMixin, ListView):
    model = Task
    template_name = 'tasks/task_list.html'
    context_object_name = 'tasks'
    paginate_by = 25

    def get_queryset(self):
        profile = get_object_or_404(UserProfile, user=self.request.user)
        qs = Task.objects.filter(parent__isnull=True).select_related(
            'assigned_to', 'assigned_by', 'created_by', 'department'
        )
        qs = _scope_tasks_by_role(qs, profile)

        q = self.request.GET.get('q', '').strip()
        if q:
            qs = qs.filter(title__icontains=q)

        assigned_name = self.request.GET.get('assigned_to_name', '').strip()
        if assigned_name:
            qs = qs.filter(
                Q(assigned_to__first_name__icontains=assigned_name) |
                Q(assigned_to__last_name__icontains=assigned_name) |
                Q(assigned_to__username__icontains=assigned_name)
            )

        dept_id = self.request.GET.get('department')
        if dept_id:
            qs = qs.filter(department_id=dept_id)

        status = self.request.GET.get('status')
        if status:
            qs = qs.filter(status=status)

        priority = self.request.GET.get('priority')
        if priority:
            qs = qs.filter(priority=priority)

        due_date = self.request.GET.get('due_date')
        if due_date:
            qs = qs.filter(due_date=due_date)

        return qs.order_by('-priority', 'due_date', 'created_at')

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx['filter_form'] = TaskFilterForm(self.request.GET or None)
        ctx['status_choices'] = Task.Status.choices
        ctx['priority_choices'] = Task.Priority.choices
        return ctx


# ---------------------------------------------------------------------------
# Legacy Task Lists (kept intact)
# ---------------------------------------------------------------------------

class TaskListListView(LoginRequiredMixin, ListView):
    model = TaskList
    template_name = 'tasks/tasklist_list.html'
    context_object_name = 'task_lists'

    def get_queryset(self):
        return TaskList.objects.filter(owner=self.request.user)


class TaskListDetailView(OwnerTaskListMixin, DetailView):
    template_name = 'tasks/tasklist_detail.html'
    context_object_name = 'task_list'

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        priority = self.request.GET.get('priority')
        status = self.request.GET.get('status')
        tasks = self.object.tasks.filter(parent__isnull=True)
        if priority:
            tasks = tasks.filter(priority=priority)
        if status:
            tasks = tasks.filter(status=status)
        ctx['tasks'] = tasks
        ctx['priority_choices'] = Task.Priority.choices
        ctx['status_choices'] = Task.Status.choices
        ctx['current_priority'] = priority
        ctx['current_status'] = status
        return ctx


class TaskListCreateView(LoginRequiredMixin, CreateView):
    model = TaskList
    form_class = TaskListForm
    template_name = 'tasks/tasklist_form.html'

    def form_valid(self, form):
        form.instance.owner = self.request.user
        return super().form_valid(form)


class TaskListUpdateView(OwnerTaskListMixin, UpdateView):
    form_class = TaskListForm
    template_name = 'tasks/tasklist_form.html'


class TaskListDeleteView(OwnerTaskListMixin, DeleteView):
    template_name = 'tasks/tasklist_confirm_delete.html'
    success_url = reverse_lazy('tasks:list-index')


# ---------------------------------------------------------------------------
# Task CRUD
# ---------------------------------------------------------------------------

NON_EMPLOYEE_ROLES = [
    UserProfile.ROLE_SENIOR_MANAGER,
    UserProfile.ROLE_MANAGER,
    UserProfile.ROLE_TEAM_LEAD,
]


class TaskCreateView(RoleRequiredMixin, CreateView):
    model = Task
    form_class = TaskForm
    template_name = 'tasks/task_form.html'
    allowed_roles = NON_EMPLOYEE_ROLES

    # Optional: allow creation from within a legacy TaskList
    def dispatch(self, request, *args, **kwargs):
        self.task_list = None
        list_pk = kwargs.get('list_pk')
        if list_pk:
            self.task_list = get_object_or_404(
                TaskList, pk=list_pk, owner=request.user
            )
        return super().dispatch(request, *args, **kwargs)

    def get_form_kwargs(self):
        kwargs = super().get_form_kwargs()
        kwargs['user'] = self.request.user
        return kwargs

    def form_valid(self, form):
        task = form.save(commit=False)
        task.created_by = self.request.user
        task.assigned_by = self.request.user
        if self.task_list:
            task.task_list = self.task_list
        # Inherit department from creator's profile if not set
        if not task.department_id:
            try:
                task.department = self.request.user.profile.department
            except UserProfile.DoesNotExist:
                pass
        task.status = Task.Status.PENDING
        task.save()
        TaskStatusHistory.objects.create(
            task=task,
            changed_by=self.request.user,
            old_status='',
            new_status=Task.Status.PENDING,
            note='Task created',
        )
        messages.success(self.request, f'Task "{task.title}" created successfully.')
        return redirect(task.get_absolute_url())

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx['task_list'] = self.task_list
        return ctx


class TaskDetailView(LoginRequiredMixin, DetailView):
    model = Task
    template_name = 'tasks/task_detail.html'
    context_object_name = 'task'

    def get_queryset(self):
        profile = get_object_or_404(UserProfile, user=self.request.user)
        qs = Task.objects.filter(parent__isnull=True).select_related(
            'assigned_to', 'assigned_by', 'created_by', 'department'
        )
        return _scope_tasks_by_role(qs, profile)

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx['subtask_form'] = SubTaskForm()
        ctx['subtasks'] = self.object.subtasks.all()
        ctx['status_history'] = self.object.status_history.select_related('changed_by').all()
        ctx['status_form'] = TaskStatusForm(initial={'status': self.object.status})
        ctx['status_choices'] = Task.Status.choices
        return ctx


# ---------------------------------------------------------------------------
# Status update (replaces toggle)
# ---------------------------------------------------------------------------

@login_required
@require_POST
def task_update_status(request, pk):
    task = get_object_or_404(Task, pk=pk, parent__isnull=True)
    profile = get_object_or_404(UserProfile, user=request.user)

    can_update = task.assigned_to_id == request.user.pk
    if not can_update and task.assigned_to_id:
        try:
            assignee_profile = UserProfile.objects.get(user_id=task.assigned_to_id)
            can_update = profile.is_superior_of(assignee_profile)
        except UserProfile.DoesNotExist:
            pass
    if not can_update and task.created_by_id == request.user.pk:
        can_update = True

    if not can_update:
        raise PermissionDenied

    new_status = request.POST.get('status')
    if new_status not in Task.Status.values:
        messages.error(request, 'Invalid status.')
        return redirect(task.get_absolute_url())

    note = request.POST.get('note', '')
    task.set_status(new_status, request.user, note=note)
    messages.success(request, f'Status updated to "{task.get_status_display()}".')
    referer = request.META.get('HTTP_REFERER')
    return redirect(referer or task.get_absolute_url())


# ---------------------------------------------------------------------------
# Subtasks
# ---------------------------------------------------------------------------

class SubTaskCreateView(LoginRequiredMixin, CreateView):
    model = Task
    form_class = SubTaskForm
    template_name = 'tasks/subtask_form.html'

    def dispatch(self, request, *args, **kwargs):
        # Allow creation if user owns the task list OR created the parent task
        self.parent_task = get_object_or_404(
            Task, pk=kwargs['pk'], parent__isnull=True
        )
        if not (
            (self.parent_task.task_list and
             self.parent_task.task_list.owner_id == request.user.pk) or
            self.parent_task.created_by_id == request.user.pk
        ):
            raise PermissionDenied
        return super().dispatch(request, *args, **kwargs)

    def form_valid(self, form):
        form.instance.parent = self.parent_task
        form.instance.task_list = self.parent_task.task_list
        form.instance.created_by = self.request.user
        form.instance.department = self.parent_task.department
        return super().form_valid(form)

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx['parent_task'] = self.parent_task
        return ctx

    def get_success_url(self):
        return self.parent_task.get_absolute_url()


@login_required
@require_POST
def subtask_toggle_complete(request, pk, sub_pk):
    parent = get_object_or_404(Task, pk=pk, parent__isnull=True)
    subtask = get_object_or_404(Task, pk=sub_pk, parent=parent)

    can_toggle = (
        (parent.task_list and parent.task_list.owner_id == request.user.pk) or
        parent.created_by_id == request.user.pk or
        subtask.assigned_to_id == request.user.pk
    )
    if not can_toggle:
        raise PermissionDenied

    if subtask.status == Task.Status.COMPLETED:
        subtask.set_status(Task.Status.PENDING, request.user)
    else:
        subtask.set_status(Task.Status.COMPLETED, request.user)
    return redirect(parent.get_absolute_url())
