from django.contrib import messages
from django.contrib.auth import login
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.decorators import login_required
from django.core.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse_lazy
from django.views.generic import (
    CreateView, DeleteView, DetailView, ListView, UpdateView, View
)

from .forms import (
    DepartmentForm, MemberRoleForm, ProfilePictureForm,
    RegisterForm, UserUpdateForm,
)
from .models import Department, UserProfile


# ── Auth ──────────────────────────────────────────────────────────────────────

class RegisterView(CreateView):
    form_class = RegisterForm
    template_name = 'accounts/register.html'
    success_url = reverse_lazy('tasks:list-index')

    def form_valid(self, form):
        response = super().form_valid(form)
        login(self.request, self.object)
        return response

    def dispatch(self, request, *args, **kwargs):
        if request.user.is_authenticated:
            return redirect('tasks:list-index')
        return super().dispatch(request, *args, **kwargs)


# ── Profile ───────────────────────────────────────────────────────────────────

class ProfileView(LoginRequiredMixin, View):
    template_name = 'accounts/profile.html'

    def _get_profile(self, user):
        profile, _ = UserProfile.objects.get_or_create(user=user)
        return profile

    def get(self, request):
        profile = self._get_profile(request.user)
        return render(request, self.template_name, {
            'user_form': UserUpdateForm(instance=request.user),
            'profile_form': ProfilePictureForm(instance=profile),
            'profile': profile,
        })

    def post(self, request):
        profile = self._get_profile(request.user)
        user_form = UserUpdateForm(request.POST, instance=request.user)
        profile_form = ProfilePictureForm(
            request.POST, request.FILES, instance=profile
        )
        if user_form.is_valid() and profile_form.is_valid():
            user_form.save()
            profile_form.save()
            messages.success(request, 'Profile updated successfully.')
            return redirect('accounts:profile')
        return render(request, self.template_name, {
            'user_form': user_form,
            'profile_form': profile_form,
            'profile': profile,
        })


class ProfilePictureDeleteView(LoginRequiredMixin, View):
    def post(self, request):
        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        if profile.picture:
            profile.picture.delete(save=True)
            messages.success(request, 'Profile picture removed.')
        return redirect('accounts:profile')


# ── Departments ───────────────────────────────────────────────────────────────

class DepartmentListView(LoginRequiredMixin, ListView):
    model = Department
    template_name = 'accounts/department_list.html'
    context_object_name = 'departments'

    def get_queryset(self):
        return Department.objects.prefetch_related('members__user')

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        try:
            ctx['my_profile'] = self.request.user.profile
        except UserProfile.DoesNotExist:
            ctx['my_profile'] = None
        return ctx


class DepartmentCreateView(LoginRequiredMixin, CreateView):
    model = Department
    form_class = DepartmentForm
    template_name = 'accounts/department_form.html'
    success_url = reverse_lazy('accounts:department-list')

    def dispatch(self, request, *args, **kwargs):
        if not request.user.is_staff:
            raise PermissionDenied
        return super().dispatch(request, *args, **kwargs)


class DepartmentUpdateView(LoginRequiredMixin, UpdateView):
    model = Department
    form_class = DepartmentForm
    template_name = 'accounts/department_form.html'
    success_url = reverse_lazy('accounts:department-list')

    def dispatch(self, request, *args, **kwargs):
        if not request.user.is_staff:
            raise PermissionDenied
        return super().dispatch(request, *args, **kwargs)


class DepartmentDeleteView(LoginRequiredMixin, DeleteView):
    model = Department
    template_name = 'accounts/department_confirm_delete.html'
    success_url = reverse_lazy('accounts:department-list')

    def dispatch(self, request, *args, **kwargs):
        if not request.user.is_staff:
            raise PermissionDenied
        return super().dispatch(request, *args, **kwargs)


class DepartmentDetailView(LoginRequiredMixin, DetailView):
    model = Department
    template_name = 'accounts/department_detail.html'
    context_object_name = 'department'

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        try:
            my_profile = self.request.user.profile
            ctx['my_profile'] = my_profile
            # Set of PKs the current user is allowed to manage (set role for)
            ctx['manageable_pks'] = {
                p.pk for p in my_profile.get_all_subordinates()
            }
        except UserProfile.DoesNotExist:
            ctx['my_profile'] = None
            ctx['manageable_pks'] = set()
        # Root members: those whose manager is null or outside this department
        dept_member_pks = set(self.object.members.values_list('pk', flat=True))
        ctx['root_members'] = [
            m for m in self.object.members.select_related('user', 'manager__user')
            if m.manager_id is None or m.manager_id not in dept_member_pks
        ]
        return ctx


# ── Member role management ────────────────────────────────────────────────────

@login_required
def manage_member_role(request, pk):
    """Allow a superior to set the role/manager of a member in their hierarchy."""
    member_profile = get_object_or_404(UserProfile, pk=pk)
    try:
        managing_profile = request.user.profile
    except UserProfile.DoesNotExist:
        raise PermissionDenied

    if not request.user.is_staff and not managing_profile.is_superior_of(member_profile):
        raise PermissionDenied

    managing_arg = None if request.user.is_staff else managing_profile

    if request.method == 'POST':
        form = MemberRoleForm(
            request.POST, instance=member_profile,
            managing_profile=managing_arg,
        )
        if form.is_valid():
            form.save()
            messages.success(
                request,
                f"{member_profile.user.username}'s role updated to "
                f"{member_profile.role_display}."
            )
            return redirect('accounts:department-list')
    else:
        form = MemberRoleForm(instance=member_profile, managing_profile=managing_arg)

    return render(request, 'accounts/manage_member_role.html', {
        'form': form,
        'member_profile': member_profile,
    })
