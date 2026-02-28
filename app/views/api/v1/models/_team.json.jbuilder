json.id resource.id
json.name resource.name
json.description resource.description
json.allow_auto_assign resource.allow_auto_assign
json.allow_inbox_bypass resource.allow_inbox_bypass
json.account_id resource.account_id
json.is_member Current.user.teams.include?(resource)
