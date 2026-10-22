-- Bot Loader by @nivalox on github

-- Main Variables
local Starter = game:GetService("StarterGui")
local bindable = Instance.new("BindableFunction")

-- Bindable
bindable.OnInvoke = function(button)
    if button == "SwordFighter" then
        loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Sword%20Fighter/source.luau"))()
    elseif button == "LoopKillSwordBot" then
        loadstring(game:HttpGet("https://raw.githubusercontent.com/TheEGodOfficial/roblox-bots-systems/refs/heads/main/Loop%20Kill%20Sword%20Bot/source.luau"))()
    end
end

-- Function
local function notification(title, text, dur, btn1, btn2)
  Starter:SetCore("SendNotification", {
      Title = title,
      Text = text,
      Duration = dur,
      Button1 = btn1,
      Button2 = btn2,
      Callback = bindable
  })
end

-- Notification
notification("Bot Loader", "Choose which bot you wwnt to use!", 6, "SwordFighter", "LoopKillSwordBot")
