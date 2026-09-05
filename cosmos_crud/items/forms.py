from django import forms

STATUS_CHOICES = [
    ('open', 'Open'),
    ('in_progress', 'In Progress'),
    ('done', 'Done'),
]


class ItemForm(forms.Form):
    name = forms.CharField(
        max_length=200,
        widget=forms.TextInput(attrs={'class': 'form-control'}),
    )
    description = forms.CharField(
        required=False,
        widget=forms.Textarea(attrs={'class': 'form-control', 'rows': 4}),
    )
    status = forms.ChoiceField(
        choices=STATUS_CHOICES,
        initial='open',
        widget=forms.Select(attrs={'class': 'form-select'}),
    )
