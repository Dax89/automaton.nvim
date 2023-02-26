local Visitor = { }
Visitor.__index = Visitor

function Visitor.start_object(_) end       -- size
function Visitor.end_object() end
function Visitor.start_object_key(_) end   -- index
function Visitor.end_object_key(_) end     -- index
function Visitor.start_object_value(_) end -- index
function Visitor.end_object_value(_) end   -- index
function Visitor.start_list(_) end         -- size
function Visitor.end_list() end
function Visitor.start_list_item(_) end    -- index
function Visitor.end_list_item(_) end      -- index
function Visitor.visit_nil() end
function Visitor.visit_boolean(_) end      -- value
function Visitor.visit_string(_) end       -- value
function Visitor.visit_number(_) end       -- value

local function create_visitor(obj)
    return setmetatable(obj or { }, Visitor)
end

local function visit(obj, v)
    local t = type(obj)

    if t == "table" then
        local size = vim.tbl_count(obj)

        if vim.tbl_islist(obj) then
            v:start_list(size)

            for i, item in ipairs(obj) do
                v:start_list_item(i)
                visit(item, v)
                v:end_list_item(i)
            end

            v:end_list()
        else
            v:start_object(size)
            local i = 0

            for key, value in pairs(obj) do
                v:start_object_key(i)
                visit(key, v)
                v:end_object_key(i)
                v:start_object_value(i)
                visit(value, v)
                v:end_object_value(i)
                i = i + 1
            end

            v:end_object()
        end
    elseif t == "number" then v:visit_number(obj)
    elseif t == "string" then v:visit_string(obj)
    elseif t == "boolean" then v:visit_boolean(obj)
    elseif t == "nil" then v:visit_nil(obj)
    else error("Unsupported type '" .. t .. "'")
    end
end

return {
    create = create_visitor,
    visit = visit,
}
