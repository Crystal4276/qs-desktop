import sys, gi
from gi.repository import Gio, GLib
conn=Gio.DBusConnection.new_for_address_sync(sys.argv[1], Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT|Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,None,None)
conn.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',('org.bluez',0)),None,0,-1,None)
a='/org/bluez/hci0'; d=a+'/dev_00_11_22_33_44_55'
objects={}; pending={}
def v(t,x):return GLib.Variant(t,x)
adapter={'Address':v('s','00:11:22:33:44:66'),'Alias':v('s','Test adapter'),'Name':v('s','Test adapter'),'Powered':v('b',True),'PowerState':v('s','on'),'Discovering':v('b',False),'Discoverable':v('b',False),'Pairable':v('b',False),'DiscoverableTimeout':v('u',180),'PairableTimeout':v('u',0),'UUIDs':v('as',[]),'Roles':v('as',['central'])}
device={'Address':v('s','00:11:22:33:44:55'),'AddressType':v('s','public'),'Name':v('s','Test device'),'Alias':v('s','Test device'),'Icon':v('s','input-gaming'),'Adapter':v('o',a),'Paired':v('b',True),'Trusted':v('b',True),'Connected':v('b',False),'Blocked':v('b',False),'LegacyPairing':v('b',False),'ServicesResolved':v('b',False),'UUIDs':v('as',[])}
def changed(path,values):
 iface=next(iter(objects[path]));objects[path][iface].update(values)
 conn.emit_signal(None,path,'org.freedesktop.DBus.Properties','PropertiesChanged',v('(sa{sv}as)',(iface,values,[])))
def method(c,s,path,iface,name,params,inv):
 if name=='GetManagedObjects':inv.return_value(v('(a{oa{sa{sv}}})',(objects,)));return
 if iface=='org.test.Control':
  action=params.unpack()[0]
  if action=='add':
   for p,i,props in [(a,'org.bluez.Adapter1',adapter),(d,'org.bluez.Device1',device)]:
    objects[p]={i:props.copy()};conn.emit_signal(None,'/','org.freedesktop.DBus.ObjectManager','InterfacesAdded',v('(oa{sa{sv}})',(p,objects[p])))
  elif action=='remove':
   for p in (d,a):
    if p in objects:conn.emit_signal(None,'/','org.freedesktop.DBus.ObjectManager','InterfacesRemoved',v('(oas)',(p,list(objects.pop(p)))))
  elif action=='chatter':
   ticks=[0]
   def tick():
    if a in objects:
     ticks[0]+=1;changed(a,{'PowerState':v('s',['on','on-disabling','off','off-enabling'][ticks[0]%4])})
    return True
   GLib.timeout_add(2,tick)
  elif action in ('audio-headphones','audio-headset','audio-speakers'):changed(d,{'Icon':v('s',action)})
  elif action=='unpaired':changed(d,{'Paired':v('b',False)})
  elif action=='enabled':changed(a,{'Powered':v('b',True),'PowerState':v('s','on')})
  elif action=='enabling':changed(a,{'PowerState':v('s','off-enabling')})
  elif action=='disabling':changed(a,{'PowerState':v('s','on-disabling')})
  elif action=='disabled':changed(a,{'Powered':v('b',False),'PowerState':v('s','off')})
  elif action in ('connected','disconnected','paired'):
   key={'connected':'Connect','disconnected':'Disconnect','paired':'Pair'}[action]
   changed(d,{'Paired':v('b',True)} if action=='paired' else {'Connected':v('b',action=='connected')})
   if key in pending:pending.pop(key).return_value(None)
  else:raise ValueError(action)
  inv.return_value(None);return
 if name in ('Connect','Disconnect','Pair'):pending[name]=inv;return
 inv.return_value(None)
def get(c,s,path,iface,name):return objects.get(path,{}).get(iface,{}).get(name)
def setp(c,s,path,iface,name,value):changed(path,{name:value});return True
def register(path,xml):
 for info in Gio.DBusNodeInfo.new_for_xml('<node>'+xml+'</node>').interfaces:
  conn.register_object(path,info,method,get,setp)
register('/', '''<interface name="org.freedesktop.DBus.ObjectManager"><method name="GetManagedObjects"><arg direction="out" type="a{oa{sa{sv}}}"/></method><signal name="InterfacesAdded"><arg type="o"/><arg type="a{sa{sv}}"/></signal><signal name="InterfacesRemoved"><arg type="o"/><arg type="as"/></signal></interface><interface name="org.test.Control"><method name="Run"><arg direction="in" type="s"/></method></interface>''')
for path,iface,props,methods in [(a,'org.bluez.Adapter1',adapter,['StartDiscovery','StopDiscovery']),(d,'org.bluez.Device1',device,['Connect','Disconnect','Pair','CancelPairing'])]:
 xml='<interface name="'+iface+'">'+''.join('<property name="'+key+'" type="'+value.get_type_string()+'" access="readwrite"/>' for key,value in props.items())+''.join('<method name="'+m+'"/>' for m in methods)+'</interface>'
 register(path,xml)
print('READY',flush=True)
GLib.MainLoop().run()
