local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; print('hello. I scene from separated thread')


require("love")
require("love_inc").require()
require('pipeline')



love.filesystem.setRequirePath("?.lua;?/init.lua;scenes/empty/?.lua")
local i18n = require("i18n")














local event_channel = love.thread.getChannel("event_channel")




local mx, my = 0, 0

local time = love.timer.getTime()
local dt = 0.

local pipeline = Pipeline.new()








local function init()
   i18n.set('en.welcome', 'welcome to this program')
   i18n.load({
      en = {
         good_bye = "good-bye!",
         age_msg = "your age is %{age}.",
         phone_msg = {
            one = "you have one new message.",
            other = "you have %{count} new messages.",
         },
      },
   })
   print("translated", i18n.translate('welcome'))
   print("translated", i18n('welcome'))

   local rendercode = [[
    --local y = graphic_command_channel:demand()
    --local x = graphic_command_channel:demand()
    --local x, y = 100, 100
    local w, h = love.graphics.getDimensions()
    local x, y = math.random() * w, math.random() * h
    love.graphics.setColor{0, 0, 0}
    love.graphics.print("TestTest", x, y)
    --]]
   pipeline:pushCode('text', rendercode)

   rendercode = [[
    local y = graphic_command_channel:demand()
    local x = graphic_command_channel:demand()
    local rad = graphic_command_channel:demand()
    love.graphics.setColor{0, 0, 1}
    love.graphics.circle('fill', x, y, rad)
    --]]
   pipeline:pushCode('circle_under_mouse', rendercode)



   pipeline:pushCode('clear', "love.graphics.clear{0.5, 0.5, 0.5}")
end

init()

while true do

   local events = event_channel:pop()
   if events then
      for _, e in ipairs(events) do
         local evtype = (e)[1]
         if evtype == "mousemoved" then
            mx = math.floor((e)[2])
            my = math.floor((e)[3])
         elseif evtype == "keypressed" then
            local key = (e)[2]
            local scancode = (e)[3]
            print('keypressed', key, scancode)
            if scancode == "escape" then
               love.event.quit()
            end
         elseif evtype == "mousepressed" then





         end
      end
   end

   local nt = love.timer.getTime()
   dt = nt - time
   time = nt




   pipeline:openAndClose('clear')

   pipeline:open('text')
   pipeline:close()

   local x, y = love.mouse.getPosition()
   local rad = 50
   pipeline:open('circle_under_mouse')
   pipeline:push(x)
   pipeline:push(y)
   pipeline:push(rad)
   pipeline:close()



   love.timer.sleep(0.001)
end









print('goodbye. I scene from separated thread')
