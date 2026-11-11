namespace Metra.Api.Domain.Forecasting;

/// <summary>
/// Pure geographic helpers for forecasting comparison. Does not invent coordinates.
/// </summary>
public static class GeoDistance
{
    private const double EarthRadiusKm = 6371.0;

    public static double? HaversineKm(double? lat1, double? lon1, double? lat2, double? lon2)
    {
        if (lat1 is null || lon1 is null || lat2 is null || lon2 is null)
            return null;
        if (!IsValidLatitude(lat1.Value) || !IsValidLatitude(lat2.Value) ||
            !IsValidLongitude(lon1.Value) || !IsValidLongitude(lon2.Value))
            return null;

        var φ1 = DegreesToRadians(lat1.Value);
        var φ2 = DegreesToRadians(lat2.Value);
        var Δφ = DegreesToRadians(lat2.Value - lat1.Value);
        var Δλ = DegreesToRadians(lon2.Value - lon1.Value);
        var a = Math.Sin(Δφ / 2) * Math.Sin(Δφ / 2) +
                Math.Cos(φ1) * Math.Cos(φ2) * Math.Sin(Δλ / 2) * Math.Sin(Δλ / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return EarthRadiusKm * c;
    }

    public static bool IsValidLatitude(double value) => value is >= -90 and <= 90;
    public static bool IsValidLongitude(double value) => value is >= -180 and <= 180;
    private static double DegreesToRadians(double degrees) => degrees * Math.PI / 180.0;
}
