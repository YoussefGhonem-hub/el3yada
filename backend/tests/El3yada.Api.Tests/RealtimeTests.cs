using System.Net.Http.Json;
using System.Text.Json;
using El3yada.Api.Features.Chat;
using El3yada.Api.Infrastructure.Realtime;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.SignalR.Client;

namespace El3yada.Api.Tests;

/// <summary>AC-13 on Windows: a running app receives the notification and the message over SignalR.</summary>
public sealed class RealtimeTests(ApiFactory api) : IClassFixture<ApiFactory>
{
    private async Task<HubConnection> ConnectAsync(Guid userId)
    {
        var token = (await api.ClientForAsync(userId)).DefaultRequestHeaders.Authorization!.Parameter!;
        var connection = new HubConnectionBuilder()
            .WithUrl(new Uri(api.Server.BaseAddress, AppHub.Path), options =>
            {
                options.Transports = HttpTransportType.LongPolling;
                options.HttpMessageHandlerFactory = _ => api.Server.CreateHandler();
                options.AccessTokenProvider = () => Task.FromResult<string?>(token);
            })
            .Build();
        await connection.StartAsync();
        return connection;
    }

    [Fact]
    public async Task Doctor_app_gets_the_message_and_the_notification_live()
    {
        await using var doctorConnection = await ConnectAsync(api.Demo.DoctorAUserId);
        var message = new TaskCompletionSource<JsonElement>();
        var notification = new TaskCompletionSource<JsonElement>();
        doctorConnection.On<JsonElement>(RealtimeEvents.ChatMessage, m => message.TrySetResult(m));
        doctorConnection.On<JsonElement>(RealtimeEvents.Notification, n => notification.TrySetResult(n));

        var patient = await api.ClientForAsync(api.Demo.PatientUserId);
        var chats = await patient.GetFromJsonAsync<List<ChatSummaryDto>>("/api/patient/chats");
        var chatId = chats!.Single(c => c.DoctorId == api.Demo.DoctorAUserId).Id;
        (await patient.PostAsJsonAsync($"/api/patient/chats/{chatId}/messages", new SendTextRequest("live?"))).EnsureSuccessStatusCode();

        var received = await message.Task.WaitAsync(TimeSpan.FromSeconds(10));
        Assert.Equal("live?", received.GetProperty("text").GetString());
        var toast = await notification.Task.WaitAsync(TimeSpan.FromSeconds(10));
        Assert.Equal("chatMessage", toast.GetProperty("type").GetString());
    }

    [Fact]
    public async Task Board_groups_check_branch_permissions()
    {
        // The reception assistant can watch doctor A's boards; doctor B can't join them.
        var branchId = await api.WithDbAsync(db => Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions
            .FirstAsync(db.Branches.Where(b => b.DoctorId == api.Demo.DoctorAUserId && b.IsDefault).Select(b => b.Id)));

        await using var assistant = await ConnectAsync(api.Demo.AssistantUserId);
        await assistant.InvokeAsync("JoinBoard", branchId);

        await using var doctorB = await ConnectAsync(api.Demo.DoctorBUserId);
        await Assert.ThrowsAsync<HubException>(() => doctorB.InvokeAsync("JoinBoard", branchId));
    }
}

