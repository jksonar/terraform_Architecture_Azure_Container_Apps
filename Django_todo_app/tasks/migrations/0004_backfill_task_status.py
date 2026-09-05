from django.db import migrations


def backfill_status(apps, schema_editor):
    Task = apps.get_model('tasks', 'Task')
    TaskStatusHistory = apps.get_model('tasks', 'TaskStatusHistory')
    UserProfile = apps.get_model('accounts', 'UserProfile')

    for task in Task.objects.all():
        if task.is_complete:
            task.status = 'completed'
            task.completed_at = task.updated_at
        else:
            task.status = 'pending'

        if task.created_by_id and task.department_id is None:
            try:
                profile = UserProfile.objects.get(user_id=task.created_by_id)
                if profile.department_id:
                    task.department_id = profile.department_id
            except UserProfile.DoesNotExist:
                pass

        task.save(update_fields=['status', 'completed_at', 'department_id'])

        TaskStatusHistory.objects.create(
            task=task,
            changed_by=None,
            old_status='',
            new_status=task.status,
            note='Migration backfill',
        )


def reverse_backfill(apps, schema_editor):
    Task = apps.get_model('tasks', 'Task')
    TaskStatusHistory = apps.get_model('tasks', 'TaskStatusHistory')
    Task.objects.update(status='pending', completed_at=None)
    TaskStatusHistory.objects.filter(note='Migration backfill').delete()


class Migration(migrations.Migration):

    dependencies = [
        ('tasks', '0003_task_new_fields'),
        ('accounts', '0002_department_userprofile_manager_userprofile_role_and_more'),
    ]

    operations = [
        migrations.RunPython(backfill_status, reverse_backfill),
    ]
