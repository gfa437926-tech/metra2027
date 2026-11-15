GRANT SELECT ON TABLE public.station_coordinates TO metra_api_runtime;
CREATE POLICY station_coordinates_api_runtime_read
ON public.station_coordinates
FOR SELECT
TO metra_api_runtime
USING (true);