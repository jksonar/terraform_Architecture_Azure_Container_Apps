from django.urls import include, path
from django.views.generic import RedirectView

urlpatterns = [
    path('cosmos_crud/', include('items.urls', namespace='items')),
    path('', RedirectView.as_view(url='/cosmos_crud/'), name='home'),
]
