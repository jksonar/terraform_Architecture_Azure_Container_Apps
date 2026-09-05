from django.urls import path
from . import views

app_name = 'tasks'

urlpatterns = [
    # Liveness probe for the Application Gateway backend health check — no auth required
    path('health/', views.health, name='health'),

    # Dashboard (login redirect target)
    path('dashboard/', views.DashboardView.as_view(), name='dashboard'),

    # Role-scoped task list (replaces assigned-tasks)
    path('task/', views.TaskListView.as_view(), name='task-list'),

    # Task creation — standalone (no list required)
    path('task/new/', views.TaskCreateView.as_view(), name='task-create'),

    # Task detail and status update
    path('task/<int:pk>/', views.TaskDetailView.as_view(), name='task-detail'),
    path('task/<int:pk>/status/', views.task_update_status, name='task-update-status'),

    # Subtasks
    path('task/<int:pk>/subtask/new/', views.SubTaskCreateView.as_view(), name='subtask-create'),
    path('task/<int:pk>/subtask/<int:sub_pk>/toggle/', views.subtask_toggle_complete, name='subtask-toggle'),

    # Legacy TaskList views — kept intact for existing data
    path('', views.TaskListListView.as_view(), name='list-index'),
    path('new/', views.TaskListCreateView.as_view(), name='list-create'),
    path('<int:pk>/', views.TaskListDetailView.as_view(), name='list-detail'),
    path('<int:pk>/edit/', views.TaskListUpdateView.as_view(), name='list-update'),
    path('<int:pk>/delete/', views.TaskListDeleteView.as_view(), name='list-delete'),

    # Legacy: create task from within a task list (kept for TaskListDetailView button)
    path('<int:list_pk>/task/new/', views.TaskCreateView.as_view(), name='task-create-in-list'),
]
