from django import forms
from django.contrib.auth.forms import UserCreationForm
from django.contrib.auth.models import User

from .models import Department, UserProfile


class RegisterForm(UserCreationForm):
    email = forms.EmailField(required=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password1', 'password2']


class UserUpdateForm(forms.ModelForm):
    email = forms.EmailField(required=True)

    class Meta:
        model = User
        fields = ['username', 'first_name', 'last_name', 'email']


class ProfilePictureForm(forms.ModelForm):
    class Meta:
        model = UserProfile
        fields = ['picture']
        widgets = {
            'picture': forms.FileInput(attrs={'accept': 'image/*'}),
        }


class DepartmentForm(forms.ModelForm):
    class Meta:
        model = Department
        fields = ['name', 'description']
        widgets = {
            'description': forms.Textarea(attrs={'rows': 3}),
        }


class MemberRoleForm(forms.ModelForm):
    """Used by senior members to set a subordinate's role and direct manager."""

    class Meta:
        model = UserProfile
        fields = ['role', 'manager', 'department']

    def __init__(self, *args, managing_profile=None, **kwargs):
        super().__init__(*args, **kwargs)
        if managing_profile is not None:
            # Manager dropdown limited to the managing user's direct subordinate chain
            subordinate_pks = [p.pk for p in managing_profile.get_all_subordinates()]
            # Include managing_profile itself as a valid manager option
            subordinate_pks.append(managing_profile.pk)
            self.fields['manager'].queryset = UserProfile.objects.filter(
                pk__in=subordinate_pks
            ).select_related('user')
            self.fields['manager'].label_from_instance = lambda obj: (
                f"{obj.user.get_full_name() or obj.user.username} ({obj.role_display})"
            )
            self.fields['manager'].required = False
            self.fields['manager'].empty_label = "— No manager —"

            # Restrict role choices: cannot assign a role >= managing user's own level
            managing_level = managing_profile.role_level
            allowed = [
                (k, v) for k, v in UserProfile.ROLE_CHOICES
                if UserProfile.ROLE_HIERARCHY.get(k, 0) < managing_level
            ]
            self.fields['role'].choices = allowed
