from django.urls import path

from . import views

app_name = 'items'

urlpatterns = [
    path('', views.item_list, name='list'),
    path('health/', views.health, name='health'),
    path('create/', views.item_create, name='create'),
    path('<str:item_id>/', views.item_detail, name='detail'),
    path('<str:item_id>/edit/', views.item_update, name='update'),
    path('<str:item_id>/delete/', views.item_delete, name='delete'),
]
