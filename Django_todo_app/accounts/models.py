from django.db import models
from django.contrib.auth.models import User


class Department(models.Model):
    name = models.CharField(max_length=200, unique=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

    class Meta:
        ordering = ['name']


class UserProfile(models.Model):
    ROLE_SENIOR_MANAGER = 'senior_manager'
    ROLE_MANAGER = 'manager'
    ROLE_TEAM_LEAD = 'team_lead'
    ROLE_EMPLOYEE = 'employee'

    ROLE_CHOICES = [
        (ROLE_SENIOR_MANAGER, 'Senior Manager'),
        (ROLE_MANAGER, 'Manager'),
        (ROLE_TEAM_LEAD, 'Team Lead'),
        (ROLE_EMPLOYEE, 'Employee'),
    ]

    ROLE_HIERARCHY = {
        ROLE_SENIOR_MANAGER: 4,
        ROLE_MANAGER: 3,
        ROLE_TEAM_LEAD: 2,
        ROLE_EMPLOYEE: 1,
    }

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    picture = models.ImageField(upload_to='profile_pictures/', blank=True, null=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default=ROLE_EMPLOYEE)
    department = models.ForeignKey(
        Department, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='members'
    )
    manager = models.ForeignKey(
        'self', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='direct_reports'
    )

    def __str__(self):
        return f"{self.user.username}'s profile"

    @property
    def role_level(self):
        return self.ROLE_HIERARCHY.get(self.role, 0)

    @property
    def role_display(self):
        return dict(self.ROLE_CHOICES).get(self.role, self.role)

    def get_all_subordinates(self):
        """BFS to collect all UserProfile objects below this one in the hierarchy."""
        result = []
        queue = list(self.direct_reports.select_related('user').all())
        while queue:
            report = queue.pop(0)
            result.append(report)
            queue.extend(list(report.direct_reports.select_related('user').all()))
        return result

    def is_superior_of(self, other_profile):
        """Return True if self is anywhere above other_profile in the chain."""
        if self.role_level <= other_profile.role_level:
            return False
        current = other_profile
        while current.manager is not None:
            if current.manager_id == self.pk:
                return True
            current = current.manager
        return False
