ALTER TABLE public.authority_memberships
  ADD CONSTRAINT authority_memberships_role_catalogue_fk
  FOREIGN KEY (membership_role_code)
  REFERENCES public.metra_role_catalogue(role_code)
  ON UPDATE RESTRICT ON DELETE RESTRICT;
ALTER TABLE public.station_assignments
  ADD CONSTRAINT station_assignments_role_catalogue_fk
  FOREIGN KEY (assignment_role_code)
  REFERENCES public.metra_role_catalogue(role_code)
  ON UPDATE RESTRICT ON DELETE RESTRICT;