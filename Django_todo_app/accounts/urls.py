from django.urls import path
from django.contrib.auth.views import LoginView, LogoutView

from .views import (
    RegisterView, ProfileView, ProfilePictureDeleteView,
    DepartmentListView, DepartmentCreateView, DepartmentDetailView,
    DepartmentUpdateView, DepartmentDeleteView, manage_member_role,
)

app_name = 'accounts'

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(template_name='accounts/login.html'), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('profile/picture/delete/', ProfilePictureDeleteView.as_view(), name='profile-picture-delete'),

    # Departments
    path('departments/', DepartmentListView.as_view(), name='department-list'),
    path('departments/new/', DepartmentCreateView.as_view(), name='department-create'),
    path('departments/<int:pk>/', DepartmentDetailView.as_view(), name='department-detail'),
    path('departments/<int:pk>/edit/', DepartmentUpdateView.as_view(), name='department-update'),
    path('departments/<int:pk>/delete/', DepartmentDeleteView.as_view(), name='department-delete'),

    # Member role management
    path('members/<int:pk>/role/', manage_member_role, name='member-role'),
]
