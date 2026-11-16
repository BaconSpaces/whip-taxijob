-- Minimal locale helper: no framework dependency, keys are dotted paths.
Locales = Locales or {}

Lang = {
    locale = 'en',
    fallback = 'en',
}

local function lookup(locale, key)
    local node = Locales[locale]
    if not node then return nil end
    for part in key:gmatch('[^%.]+') do
        if type(node) ~= 'table' then return nil end
        node = node[part]
    end
    return type(node) == 'string' and node or nil
end

--- Lang:t('error.not_in_bus') or Lang:t('success.paid', amount)
function Lang:t(key, ...)
    local text = lookup(self.locale, key) or lookup(self.fallback, key)
    if not text then return key end
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end
