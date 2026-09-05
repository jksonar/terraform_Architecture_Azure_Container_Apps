import uuid
from datetime import datetime, timezone

from django.contrib import messages
from django.http import JsonResponse
from django.shortcuts import redirect, render

from . import cosmos_client as db
from .forms import ItemForm


def item_list(request):
    items = db.list_items()
    return render(request, 'items/item_list.html', {'items': items})


def item_create(request):
    if request.method == 'POST':
        form = ItemForm(request.POST)
        if form.is_valid():
            item = {
                'id': str(uuid.uuid4()),
                **form.cleaned_data,
                'created_at': datetime.now(timezone.utc).isoformat(),
            }
            db.create_item(item)
            messages.success(request, 'Item created.')
            return redirect('items:list')
    else:
        form = ItemForm()
    return render(request, 'items/item_form.html', {'form': form, 'title': 'Create item'})


def item_detail(request, item_id):
    item = db.get_item(item_id)
    if item is None:
        messages.error(request, 'Item not found.')
        return redirect('items:list')
    return render(request, 'items/item_detail.html', {'item': item})


def item_update(request, item_id):
    item = db.get_item(item_id)
    if item is None:
        messages.error(request, 'Item not found.')
        return redirect('items:list')

    if request.method == 'POST':
        form = ItemForm(request.POST)
        if form.is_valid():
            item.update(form.cleaned_data)
            db.update_item(item_id, item)
            messages.success(request, 'Item updated.')
            return redirect('items:detail', item_id=item_id)
    else:
        form = ItemForm(initial=item)
    return render(request, 'items/item_form.html', {'form': form, 'title': 'Edit item'})


def item_delete(request, item_id):
    item = db.get_item(item_id)
    if item is None:
        messages.error(request, 'Item not found.')
        return redirect('items:list')

    if request.method == 'POST':
        db.delete_item(item_id)
        messages.success(request, 'Item deleted.')
        return redirect('items:list')

    return render(request, 'items/item_confirm_delete.html', {'item': item})


def health(request):
    if db.ping():
        return JsonResponse({'status': 'ok'})
    return JsonResponse({'status': 'error'}, status=503)
