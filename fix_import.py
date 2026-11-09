import pathlib
p = pathlib.Path("flight/views.py")
t = p.read_text(encoding="utf-8")
if "auth_login" not in t.split("\n")[0:15].__str__():
    # add import at very top
    t = "from django.contrib.auth import login as auth_login\n" + t
    p.write_text(t, encoding="utf-8")
    print("IMPORT ADDED")
else:
    print("ALREADY THERE")
