from django.contrib import admin

from .models import Department, UserProfile


@admin.register(Department)
class DepartmentAdmin(admin.ModelAdmin):
    list_display = ['name', 'member_count', 'created_at']
    search_fields = ['name']

    def member_count(self, obj):
        return obj.members.count()
    member_count.short_description = 'Members'


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'role', 'department', 'manager', 'picture']
    list_filter = ['role', 'department']
    search_fields = ['user__username', 'user__email']
    autocomplete_fields = ['department']
    raw_id_fields = ['manager']
