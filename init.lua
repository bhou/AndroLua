require 'android.import'

function goapp(mod,arg)
	service:launchLuaActivity(activity,mod,arg)
end

function killapp()
-- until we get it right...
--~     if current_activity ~= activity then
--~         current_activity:finish()
--~     end
end

PK = luajava.package
W = PK 'android.widget'
G = PK 'android.graphics'
V = PK 'android.view'
A = PK 'android'
L = PK 'java.lang'
U = PK 'java.util'

ss = L.String{'one','two'}
