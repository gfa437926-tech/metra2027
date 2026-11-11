using Xunit;
using System.Text.Json;
using Metra.Api.Features.Observations;

namespace Metra.Api.Tests.Domain;

/// <summary>
/// Loads shared JSON fixtures from contracts/observation-v1 so .NET, Flutter, and Angular
/// validate the same canonical cases.
/// </summary>
public sealed class SharedObservationContractFixturesTests
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    [Fact]
    public void Shared_fixtures_match_ObservationFieldContract_expectations()
    {
        var fixturesDir = LocateFixturesDirectory();
        var manifestPath = Path.Combine(fixturesDir, "manifest.json");
        Assert.True(File.Exists(manifestPath), $"Missing manifest at {manifestPath}");

        using var manifestDoc = JsonDocument.Parse(File.ReadAllText(manifestPath));
        var files = manifestDoc.RootElement.GetProperty("fixtures").EnumerateArray()
            .Select(e => e.GetString()!)
            .ToList();

        Assert.NotEmpty(files);

        foreach (var fileName in files)
        {
            var path = Path.Combine(fixturesDir, fileName);
            Assert.True(File.Exists(path), $"Missing fixture {path}");
            using var doc = JsonDocument.Parse(File.ReadAllText(path));
            var root = doc.RootElement;
            var id = root.GetProperty("id").GetString()!;
            var observationType = root.GetProperty("observationType").GetString()!;
            var expectValid = root.GetProperty("expectValid").GetBoolean();
            var expectedErrorFields = root.GetProperty("expectErrorFields").EnumerateArray()
                .Select(e => e.GetString()!)
                .ToHashSet(StringComparer.Ordinal);

            // Rebuild payload object for ObservationFieldContract.ValidateSubmission
            using var payloadStream = new MemoryStream();
            using (var writer = new Utf8JsonWriter(payloadStream))
            {
                writer.WriteStartObject();
                if (root.TryGetProperty("reportType", out var rt) && rt.ValueKind != JsonValueKind.Null)
                {
                    writer.WriteString("reportType", rt.GetString());
                }
                if (root.TryGetProperty("responsibilityAgreement", out var ra))
                {
                    writer.WriteBoolean("responsibilityAgreement", ra.GetBoolean());
                }
                writer.WritePropertyName("values");
                root.GetProperty("values").WriteTo(writer);
                writer.WriteEndObject();
            }

            var payloadJson = System.Text.Encoding.UTF8.GetString(payloadStream.ToArray());
            using var payloadDoc = JsonDocument.Parse(payloadJson);
            var issues = ObservationFieldContract.ValidateSubmission(observationType, payloadDoc.RootElement);
            var issueFields = issues.Select(i => i.Field).ToHashSet(StringComparer.Ordinal);

            if (expectValid)
            {
                Assert.True(issues.Count == 0,
                    $"Fixture {id} expected valid but got: {string.Join("; ", issues.Select(i => $"{i.Field}:{i.Message}"))}");
            }
            else
            {
                Assert.True(issues.Count > 0, $"Fixture {id} expected validation errors but passed.");
                foreach (var field in expectedErrorFields)
                {
                    Assert.True(issueFields.Contains(field),
                        $"Fixture {id} expected error field '{field}' but got [{string.Join(", ", issueFields)}]");
                }
            }
        }
    }

    private static string LocateFixturesDirectory()
    {
        // Metra.Api.Tests -> backend -> repo root
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "contracts", "observation-v1", "fixtures");
            if (Directory.Exists(candidate) && File.Exists(Path.Combine(candidate, "manifest.json")))
                return candidate;
            dir = dir.Parent;
        }

        throw new DirectoryNotFoundException(
            "Could not locate contracts/observation-v1/fixtures relative to the test output directory.");
    }
}
