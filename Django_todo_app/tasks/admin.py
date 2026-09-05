from django.contrib import admin
from .models import TaskList, Task, TaskStatusHistory


@admin.register(TaskList)
class TaskListAdmin(admin.ModelAdmin):
    list_display = ['name', 'owner', 'total_task_count', 'created_at']
    list_filter = ['owner']
    search_fields = ['name', 'owner__username']

    def total_task_count(self, obj):
        return obj.total_task_count
    total_task_count.short_description = 'Tasks'


@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ['title', 'status', 'priority', 'department', 'assigned_to', 'assigned_by', 'due_date', 'completed_at']
    list_filter = ['status', 'priority', 'department']
    search_fields = ['title', 'assigned_to__username', 'department__name']
    raw_id_fields = ['parent', 'task_list']
    readonly_fields = ['created_at', 'updated_at', 'completed_at', 'assigned_by', 'created_by']


@admin.register(TaskStatusHistory)
class TaskStatusHistoryAdmin(admin.ModelAdmin):
    list_display = ['task', 'old_status', 'new_status', 'changed_by', 'changed_at']
    list_filter = ['new_status']
    search_fields = ['task__title', 'changed_by__username']
    readonly_fields = ['task', 'old_status', 'new_status', 'changed_by', 'changed_at', 'note']

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
