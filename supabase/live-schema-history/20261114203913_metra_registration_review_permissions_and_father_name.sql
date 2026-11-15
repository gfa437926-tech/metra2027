begin;

alter table iam.user_profiles
  add column if not exists father_name text;

insert into iam.permissions (
  permission_code, name_ar, name_en, description, permission_domain
)
values
  (
    'registrations.review_station',
    'مراجعة طلبات الانتساب على مستوى المحطة',
    'Review station-level registration requests',
    'Allows reviewing registration requests for stations within the assigned station scope.',
    'iam'
  ),
  (
    'registrations.review_organization',
    'مراجعة طلبات الانتساب على مستوى الجهة',
    'Review organization-level registration requests',
    'Allows final organization-level review of registration requests within the assigned organization scope.',
    'iam'
  )
on conflict (permission_code) do update
set name_ar = excluded.name_ar,
    name_en = excluded.name_en,
    description = excluded.description,
    permission_domain = excluded.permission_domain;

insert into iam.role_permissions (role_id, permission_id)
select r.id, p.id
from iam.roles r
join iam.permissions p on p.permission_code = 'registrations.review_station'
where r.role_code in ('station_manager', 'platform_admin')
on conflict do nothing;

insert into iam.role_permissions (role_id, permission_id)
select r.id, p.id
from iam.roles r
join iam.permissions p on p.permission_code = 'registrations.review_organization'
where r.role_code in ('organization_admin', 'platform_admin')
on conflict do nothing;

commit;