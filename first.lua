easy = require 'android'.new()

local smm = bind 'android.text.method.ScrollingMovementMethod':getInstance()

function easy.create(me)

    local executeBtn = me:button 'Execute!'
    local source = me:editText {
        size = '20sp',
        typeface = 'monospace',
        gravity = 'top|left'
    }
    local status = me:textView {'TextView', maxLines = 5 }
    status:setMovementMethod(smm) -- make us scrollable!

    source:setText "print 'hello, world!'"

    local layout =  me:vbox{
        executeBtn,
        source,'+',
        status
    }

    return layout
end

return easy