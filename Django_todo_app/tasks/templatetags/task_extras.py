from django import template

register = template.Library()


@register.filter
def priority_badge_class(value):
    return {4: 'danger', 3: 'warning', 2: 'info', 1: 'secondary'}.get(int(value), 'secondary')


@register.filter
def status_badge_class(value):
    return {
        'pending': 'warning text-dark',
        'in_progress': 'info text-dark',
        'completed': 'success',
        'not_completed': 'danger',
    }.get(value, 'secondary')
