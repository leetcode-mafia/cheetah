using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Text.Json.Serialization;

public class OpenAIClient
{
    private readonly string _apiKey;
    private readonly HttpClient _httpClient;
    private readonly string _dalleModel = "dall-e-2";
    private readonly string _moderationModel = "omni-moderation-latest";

    public OpenAIClient(string apiKey)
    {
        _apiKey = apiKey;
        _httpClient = new HttpClient();
        _httpClient.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", _apiKey);
    }

    public async Task<string> GenerateImageAsync(string prompt)
    {
        var url = "https://api.openai.com/v1/images/generations";
        var requestBody = new
        {
            model = _dalleModel,
            prompt = prompt,
            n = 1,
            size = "1024x1024"
        };
        var json = JsonSerializer.Serialize(requestBody);
        var content = new StringContent(json, Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync(url, content);
        response.EnsureSuccessStatusCode();

        var responseJson = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(responseJson);
        var imageUrl = doc.RootElement.GetProperty("data")[0].GetProperty("url").GetString();

        return imageUrl;
    }
    public async Task<ModerationResponse> ModerateContentAsync(string input)
    {
        var url = "https://api.openai.com/v1/moderations";
        var requestBody = new
        {
            model = _moderationModel,
            input = input
        };
        var json = JsonSerializer.Serialize(requestBody);
        var content = new StringContent(json, Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync(url, content);
        response.EnsureSuccessStatusCode();

        var responseJson = await response.Content.ReadAsStringAsync();

        var options = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        };

        var moderationResponse = JsonSerializer.Deserialize<ModerationResponse>(responseJson, options);
        return moderationResponse;
    }

}
