print('hello. I scene from separated thread')

require "love"
require "love_inc".require_pls_nographic()
require 'pipeline'

love.filesystem.setRequirePath("?.lua;?/init.lua;scenes/empty_mt/?.lua")

local cpath = love.filesystem.getCRequirePath()
print('cpath before', cpath)
print('package.cpath', package.cpath)
print('package.cpath after', package.cpath)
cpath = love.filesystem.getCRequirePath()
print('cpath after', cpath)

--[[
require 'ffi'
local C = require 'ffi'
C.cdef [[
int32_t add(int32_t a, int32_t b);

typedef void(*Callback)(int32_t a, int32_t b, void* ptr, int64_t f);
typedef void(*Callback_noargs)();
typedef void(*Callback_1arg)(int32_t a);

void pump_iron(Callback a, Callback b);
void pump_iron_noargs(Callback_noargs a);
void pump_iron_1arg(Callback_1arg a);
]]
--]]

local inspect = require "inspect"

local ddd = require 'ddd'
local ok, errmsg = pcall(function()
    ddd.hello("sneg")

    print('get_table', inspect(ddd.get_table()))

    ddd.init()
end) as (boolean, string)

if not ok then
    print('errmsg', errmsg)
end

--[[
local ddd_C = C.load 'ddd' as DDD
local a, b = 200, 1
--print('add', ddd_C.add(a, b))

local function test_external_add()
    local random = love.math.random
    local format = string.format
    for i = 1, 1000000 do
        local a, b = random(1, 100000), random(1, 100000)
        --print('a, b', a, b)
        local should_be = a + b
        local res = ddd_C.add(a, b)
        if should_be ~= res then
            error(format("%d + %d ~= %d, res = %d", a, b, should_be, res))
        end
    end
end

local function pumper1(a: number, b: number, ptr: any, f: number)
    assert(a + 1 == b)
    print('pumper3')
    print('a', a)
    print('b', b)
    print('ptr', ptr)
    print('f', f)
end

local function pumper2(a: number, b: number, ptr: any, f: number)
    assert(a - 1 == b)
    print('pumper2')
    print('a', a)
    print('b', b)
    print('ptr', ptr)
    print('f', f)
end

local function pumper_noargs()
    print('pumper_noargs')
end

local function pump_iron_1arg(a: number)
    print('pump_iron_1arg', a)
end

local function test_pump_iron()
    local random = love.math.random
    local format = string.format
    local cb1 = C.cast('Callback', pumper1) as DDD.Pumper
    local cb2 = C.cast('Callback', pumper2) as DDD.Pumper

    local cb_noargs = C.cast('Callback_noargs', pumper_noargs) as DDD.Pumper_noarg
    local cb_1arg = C.cast('Callback_1arg', pump_iron_1arg) as DDD.Pumper_1arg

    for i = 1, 2 do
    --for i = 1, 10 do
        --ddd_C.pump_iron(cb1, cb2)
    end
    ddd_C.pump_iron_noargs(cb_noargs)
    --ddd_C.pump_iron_1arg(cb_1arg)
end

--test_external_add()
--test_pump_iron()
--]]

--local ddd = require 'ddd'
--local ddd = require 'ddd/target/debug/ddd'

local event_channel = love.thread.getChannel("event_channel")

local mx, my = 0, 0

local last_render: number

local pipeline = Pipeline.new()

-- Как часто перекомпилировать код рисовки?
-- Варианты - 
--  * по таймеру
--  * используя метод :peek() на каждой итерации цикла
-- Сейчас функция компилируется один раз при загрузке файла исходного текста
-- потока.

local function init()
    local rendercode = [[
    while true do
        local w, h = love.graphics.getDimensions()
        local x, y = math.random() * w, math.random() * h
        love.graphics.setColor{0, 0, 0}
        love.graphics.print("TestTest", x, y)

        coroutine.yield()
    end
    ]]
    pipeline:pushCode('text', rendercode)

    rendercode = [[
    while true do
        local y = graphic_command_channel:demand()
        local x = graphic_command_channel:demand()
        local rad = graphic_command_channel:demand()
        love.graphics.setColor{0, 0, 1}
        love.graphics.circle('fill', x, y, rad)

        coroutine.yield()
    end
    ]]
    pipeline:pushCode('circle_under_mouse', rendercode)

    -- Допустимо-ли переопределение функций? Или добавить специальный флаг?
    -- Нормально-ли использовать константы?
    pipeline:pushCode('clear', [[
    while true do
        love.graphics.clear{0.5, 0.5, 0.5}

        coroutine.yield()
    end
    ]])

    --[[
    -- Добавлять-ли такую функцию? Будет использоваться?
    -- Стоимость реализации и возможности применения.
    pipeline:pushCodes({
        { 
            'text',
            'code',
        },
        {},
        {},
    })
    --]]

    last_render = love.timer.getTime()
end

local function render()
    pipeline:openAndClose('clear')

    pipeline:open('text')
    pipeline:close()

    local x, y = love.mouse.getPosition()
    --print('mouse x, y', x, y)
    local rad = 50
    pipeline:open('circle_under_mouse')
    pipeline:push(y)
    pipeline:push(x)
    pipeline:push(rad)
    pipeline:close()

    pipeline:sync()
end

local function mainloop()
    while true do
        --print('mainloop iter')
        local events = event_channel:pop() as {any}
        if events then
            for _, e in ipairs(events) do
                local evtype: string = (e as {string})[1]
                if evtype == "mousemoved" then
                    mx = math.floor((e as {number})[2])
                    my = math.floor((e as {number})[3])
                elseif evtype == "keypressed" then
                    local key = (e as {string})[2]
                    local scancode = (e as {string})[3]
                    --print('keypressed', key, scancode)
                    if scancode == "escape" then
                        love.event.quit()
                    end
                elseif evtype == "mousepressed" then
                    --local x: number = (e as {number})[2]
                    --local y: number = (e as {number})[3]
                    --local button: number = (e as {number})[4]
                    --local istouch: boolean = (e as {boolean})[5]
                    --local presses: number = (e as {number})[6]
                end
            end
        end
        
        local nt = love.timer.getTime()
        --local pause = 1. / 10.
        local pause = 1. / 300.
        if nt - last_render >= pause then
            last_render = nt
            --local msg = 'love.timer.getTime() = %f'
            --print(colorize('%{blue}' .. format(msg, love.timer.getTime())))

            render()
        end
        --]]

        --render()

        --[[
        Ограничение кадров в секунду до 60
        --]]

        --love.timer.sleep(0.0008)
        love.timer.sleep(0.0001)
    end
end

init()
mainloop()

print('goodbye. I scene from separated thread')
