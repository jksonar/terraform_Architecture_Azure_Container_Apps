from django import forms
from django.contrib.auth.models import User

from accounts.models import Department, UserProfile
from .models import TaskList, Task


class TaskListForm(forms.ModelForm):
    class Meta:
        model = TaskList
        fields = ['name', 'description']
        widgets = {
            'description': forms.Textarea(attrs={'rows': 3}),
        }


class TaskForm(forms.ModelForm):
    class Meta:
        model = Task
        fields = ['title', 'description', 'department', 'priority', 'due_date', 'assigned_to']
        widgets = {
            'description': forms.Textarea(attrs={'rows': 3}),
            'due_date': forms.DateInput(attrs={'type': 'date'}),
        }

    def __init__(self, *args, user=None, **kwargs):
        super().__init__(*args, **kwargs)

        self.fields['description'].required = True
        self.fields['due_date'].required = True
        self.fields['assigned_to'].required = True
        self.fields['assigned_to'].empty_label = '— Select assignee —'

        if user is not None:
            try:
                profile = user.profile
                subordinates = profile.get_all_subordinates()
                sub_user_ids = [p.user_id for p in subordinates]
                assigned_qs = User.objects.filter(pk__in=sub_user_ids).order_by('username')
            except Exception:
                assigned_qs = User.objects.none()
        else:
            assigned_qs = User.objects.none()

        self.fields['assigned_to'].queryset = assigned_qs

        # Department: Senior Managers pick any; others locked to their own dept
        self._user = user
        if user is not None:
            try:
                profile = user.profile
                if profile.role == UserProfile.ROLE_SENIOR_MANAGER:
                    self.fields['department'].queryset = Department.objects.all()
                    self.fields['department'].required = True
                else:
                    own_dept = profile.department
                    if own_dept:
                        self.fields['department'].queryset = Department.objects.filter(pk=own_dept.pk)
                        self.fields['department'].initial = own_dept
                    else:
                        self.fields['department'].queryset = Department.objects.none()
                    self.fields['department'].required = True
                    self.fields['department'].widget.attrs['disabled'] = 'disabled'
            except Exception:
                self.fields['department'].queryset = Department.objects.all()

    def clean_department(self):
        # Re-inject the user's department when the field is disabled (Django ignores disabled fields)
        if self._user is not None:
            try:
                profile = self._user.profile
                if profile.role != UserProfile.ROLE_SENIOR_MANAGER:
                    return profile.department
            except Exception:
                pass
        return self.cleaned_data.get('department')


class SubTaskForm(forms.ModelForm):
    class Meta:
        model = Task
        fields = ['title', 'priority', 'due_date']
        widgets = {
            'due_date': forms.DateInput(attrs={'type': 'date'}),
        }


class TaskStatusForm(forms.Form):
    status = forms.ChoiceField(choices=Task.Status.choices)
    note = forms.CharField(
        required=False,
        widget=forms.Textarea(attrs={'rows': 2, 'placeholder': 'Optional note…'}),
    )


class TaskFilterForm(forms.Form):
    q = forms.CharField(
        required=False,
        label='Search title',
        widget=forms.TextInput(attrs={'placeholder': 'Search by title…'}),
    )
    assigned_to_name = forms.CharField(
        required=False,
        label='Employee name',
        widget=forms.TextInput(attrs={'placeholder': 'Employee name…'}),
    )
    department = forms.ModelChoiceField(
        queryset=Department.objects.all(),
        required=False,
        empty_label='All departments',
    )
    status = forms.ChoiceField(
        choices=[('', 'All statuses')] + list(Task.Status.choices),
        required=False,
    )
    priority = forms.ChoiceField(
        choices=[('', 'All priorities')] + list(Task.Priority.choices),
        required=False,
    )
    due_date = forms.DateField(
        required=False,
        widget=forms.DateInput(attrs={'type': 'date'}),
    )
