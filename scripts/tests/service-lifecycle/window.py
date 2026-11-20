import sys,gi,json
from pathlib import Path
gi.require_version('Gtk','3.0')
from gi.repository import Gtk,GLib
GLib.set_prgname(sys.argv[3] if len(sys.argv)>3 else 'nemo');Gtk.init([])
w=Gtk.Window(title=sys.argv[2]);w.set_default_size(350,200);w.connect('destroy',Gtk.main_quit);w.show_all()
command=Path(sys.argv[1]);last=''
def poll():
 global last
 if command.exists():
  text=command.read_text()
  if text!=last:
   last=text
   if text=='CLOSE':w.destroy();return False
   w.set_title(text)
 return True
if len(sys.argv)>4:
 counter=[0]
 def tick():
  counter[0]+=1;w.set_title(str(counter[0]%100)+'% Copying "A" to "B"');return True
 GLib.timeout_add(2,tick)
GLib.timeout_add(50,poll);Gtk.main()
