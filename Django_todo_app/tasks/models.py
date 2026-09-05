from django.db import models
from django.contrib.auth.models import User
from django.urls import reverse
from django.utils import timezone


class TaskList(models.Model):
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='task_lists')
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        unique_together = [['owner', 'name']]

    def __str__(self):
        return self.name

    def get_absolute_url(self):
        return reverse('tasks:list-detail', kwargs={'pk': self.pk})

    @property
    def completion_percentage(self):
        tasks = self.tasks.filter(parent__isnull=True)
        total = tasks.count()
        if total == 0:
            return 0
        done = tasks.filter(status=Task.Status.COMPLETED).count()
        return int((done / total) * 100)

    @property
    def open_task_count(self):
        return self.tasks.filter(
            parent__isnull=True,
            status__in=[Task.Status.PENDING, Task.Status.IN_PROGRESS]
        ).count()

    @property
    def total_task_count(self):
        return self.tasks.filter(parent__isnull=True).count()


class Task(models.Model):

    class Priority(models.IntegerChoices):
        LOW = 1, 'Low'
        MEDIUM = 2, 'Medium'
        HIGH = 3, 'High'
        URGENT = 4, 'Urgent'

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        IN_PROGRESS = 'in_progress', 'In Progress'
        COMPLETED = 'completed', 'Completed'
        NOT_COMPLETED = 'not_completed', 'Not Completed'

    task_list = models.ForeignKey(
        TaskList, on_delete=models.CASCADE,
        related_name='tasks', null=True, blank=True
    )
    parent = models.ForeignKey(
        'self', on_delete=models.CASCADE,
        related_name='subtasks', null=True, blank=True
    )
    created_by = models.ForeignKey(
        User, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='created_tasks'
    )
    assigned_by = models.ForeignKey(
        User, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='assigned_by_tasks'
    )
    assigned_to = models.ForeignKey(
        User, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='assigned_tasks'
    )
    department = models.ForeignKey(
        'accounts.Department', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='tasks'
    )
    title = models.CharField(max_length=300)
    description = models.TextField(blank=True)
    priority = models.IntegerField(choices=Priority.choices, default=Priority.MEDIUM)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )
    is_complete = models.BooleanField(default=False)  # kept for legacy TaskList views
    due_date = models.DateField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-priority', 'due_date', 'created_at']

    def __str__(self):
        return self.title

    def get_absolute_url(self):
        return reverse('tasks:task-detail', kwargs={'pk': self.pk})

    @property
    def is_subtask(self):
        return self.parent_id is not None

    @property
    def progress(self):
        if self.status == self.Status.COMPLETED:
            return 100
        subtasks = self.subtasks.all()
        total = subtasks.count()
        if total == 0:
            return 0
        done = subtasks.filter(status=self.Status.COMPLETED).count()
        return int((done / total) * 100)

    @property
    def owner(self):
        if self.task_list:
            return self.task_list.owner
        if self.parent:
            return self.parent.owner
        return None

    @property
    def priority_css(self):
        return {4: 'urgent', 3: 'high', 2: 'medium', 1: 'low'}.get(self.priority, 'low')

    def set_status(self, new_status, changed_by, note=''):
        old_status = self.status
        self.status = new_status
        if new_status in (self.Status.COMPLETED, self.Status.NOT_COMPLETED):
            self.completed_at = timezone.now()
            self.is_complete = (new_status == self.Status.COMPLETED)
        else:
            self.completed_at = None
            self.is_complete = False
        self.save(update_fields=['status', 'is_complete', 'completed_at', 'updated_at'])
        TaskStatusHistory.objects.create(
            task=self,
            changed_by=changed_by,
            old_status=old_status,
            new_status=new_status,
            note=note,
        )

    def can_toggle(self, user):
        return (
            self.assigned_to_id == user.pk
            or self.created_by_id == user.pk
            or (self.task_list and self.task_list.owner_id == user.pk)
        )


class TaskStatusHistory(models.Model):
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name='status_history')
    changed_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True
    )
    old_status = models.CharField(max_length=20, blank=True)
    new_status = models.CharField(max_length=20)
    changed_at = models.DateTimeField(auto_now_add=True)
    note = models.TextField(blank=True)

    class Meta:
        ordering = ['-changed_at']

    def __str__(self):
        return f"{self.task} → {self.new_status} at {self.changed_at:%Y-%m-%d %H:%M}"
