# Product Requirements Document (PRD)

## Employee Task Management System

**Version:** 1.0
**Author:** Jay Sonar
**Date:** August 1, 2026

---

# 1. Project Overview

## Project Name

**Employee Task Management System (ETMS)**

## Purpose

The Employee Task Management System is an internal web application designed to manage tasks across an organization's hierarchy. The system allows senior employees to assign work to their subordinates while maintaining accountability and complete task history.

The application ensures that:

* Tasks are assigned according to organizational hierarchy.
* Employees update task progress.
* Task history is never lost.
* Management can monitor employee productivity.

---

# 2. Objectives

* Manage organization hierarchy.
* Assign tasks based on employee roles.
* Track task progress.
* Prevent unauthorized task modification.
* Maintain complete audit history.
* Generate productivity reports.

---

# 3. User Roles

## 1. Senior Manager

Permissions

* Create Task
* Assign task to

  * Manager
  * Team Leader
  * Employee
* View all departments
* View all tasks
* View reports
* View employee performance

Cannot

* Delete completed tasks

---

## 2. Manager

Permissions

* Create Task
* Assign task to

  * Team Leader
  * Employee
* View own department tasks
* View assigned tasks

Cannot

* Assign task to Senior Manager
* Delete tasks

---

## 3. Team Leader

Permissions

* Create Task
* Assign task only to Employees
* View team tasks
* Update task status

Cannot

* Assign task to Manager
* Delete tasks

---

## 4. Employee

Permissions

* View assigned tasks
* Update task status

Cannot

* Create task
* Edit task
* Delete task
* Reassign task

---

# 4. Department Management

Example Departments

* IT
* Accounts
* HR
* Marketing
* Sales
* Administration

Example

```
IT Department

Senior Manager

    Manager

        Team Leader

            Employee 1
            Employee 2
            Employee 3
```

---

# 5. Organization Hierarchy

```
Senior Manager

      ↓

Manager

      ↓

Team Leader

      ↓

Employee
```

Permission Matrix

| Action             | Senior Manager | Manager | Team Leader | Employee |
| ------------------ | -------------- | ------- | ----------- | -------- |
| Create Task        | Yes            | Yes     | Yes         | Yes      |
| Assign Manager     | Yes            | No      | No          | No       |
| Assign Team Leader | Yes            | Yes     | No          | No       |
| Assign Employee    | Yes            | Yes     | Yes         | No       |
| Update Status      | Yes            | Yes     | Yes         | Yes      |
| Delete Task        | No             | No      | No          | No       |
| Edit Task          | Yes            | Yes     | Yes         | No       |

---

# 6. Task Lifecycle

```
Task Created

↓

Assigned

↓

Employee Working

↓

Completed

OR

Not Completed

↓

Archived
```

Tasks remain permanently stored.

---

# 7. Task Status

Possible Status

* Pending
* In Progress
* Completed
* Not Completed

Only status can be updated.

Everything else remains locked after assignment.

---

# 8. Task Module

Task Information

| Field           | Required |
| --------------- | -------- |
| Task Title      | Yes      |
| Description     | Yes      |
| Department      | Yes      |
| Priority        | Yes      |
| Assigned By     | Auto     |
| Assigned To     | Yes      |
| Due Date        | Yes      |
| Created Date    | Auto     |
| Status          | Pending  |
| Completion Date | Auto     |

---

# 9. Task Rules

## Create Task

Allowed by

* Senior Manager
* Manager
* Team Leader

---

## Edit Task

Not Allowed

Reason

Prevent changing assigned work.

---

## Delete Task

Not Allowed

Reason

Maintain audit history.

---

## Update Status

Allowed

Possible Updates

Pending

↓

In Progress

↓

Completed

or

Not Completed

---

# 10. Dashboard

## Senior Manager Dashboard

Show

* Total Departments
* Total Employees
* Pending Tasks
* Completed Tasks
* Overdue Tasks
* Department Performance
* Employee Performance

---

## Manager Dashboard

Show

* Team Members
* Assigned Tasks
* Completed Tasks
* Pending Tasks

---

## Team Leader Dashboard

Show

* Team Tasks
* Completed Tasks
* Pending Tasks

---

## Employee Dashboard

Show

* My Tasks
* Due Today
* Pending
* Completed
* Not Completed

---

# 11. Search & Filters

Search by

* Employee Name
* Department
* Status
* Priority
* Due Date
* Task Title

---

# 12. Notifications

Notify when

* New task assigned
* Task completed
* Task overdue
* Due date approaching

---

# 13. Reports

Generate reports by

* Employee
* Department
* Manager
* Date Range
* Task Status
* Priority

Export

* PDF
* Excel
* CSV

---

# 14. Database Entities

## Department

* id
* name
* description

---

## Employee

* id
* employee_id
* first_name
* last_name
* email
* phone
* department_id
* role
* reporting_manager
* status

---

## Task

* id
* title
* description
* priority
* due_date
* assigned_by
* assigned_to
* department
* status
* completed_at
* created_at
* updated_at

---

# 15. Business Rules

### Rule 1

Senior Manager can assign tasks to:

* Manager
* Team Leader
* Employee

---

### Rule 2

Manager can assign tasks to

* Team Leader
* Employee

---

### Rule 3

Team Leader can assign tasks only to Employees.

---

### Rule 4

Employees cannot assign tasks.

---

### Rule 5

After assignment

* Task cannot be edited.
* Task cannot be deleted.

---

### Rule 6

Employees can only update the task status.

---

### Rule 7

Every task must have

* Creator
* Assignee
* Timestamp
* Status history

---

# 16. Non-Functional Requirements

### Security

* Role-Based Access Control (RBAC)
* Secure authentication
* Encrypted passwords
* Session timeout

### Performance

* Dashboard loads within 3 seconds
* Support 10,000+ tasks
* Support 1,000+ employees

### Reliability

* 99.9% uptime
* Daily backups
* Audit logging for all task actions

---

# 17. Future Enhancements

* Task comments and discussions
* File attachments
* Task checklists
* Recurring tasks
* Task templates
* Email and WhatsApp notifications
* Calendar integration
* Mobile application
* Employee leave integration
* KPI and productivity analytics
* AI-powered task prioritization

