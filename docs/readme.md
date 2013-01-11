# Lua for Android using AndroLua

## Advantages

The Android Java development process is fairly clumsy, although the IDE support is
excellent. ...

A dynamic language allows a much more interactive development flow, especially if
there is an interactive prompt (REPL) hosted on the development machine. This allows
you to learn a large API by experimentation, and test out small snippets of code,
without actually having to rebuild, reinstall and relaunch.  The further advantage
of Lua is its small footprint - the dynamic library `libluajava.so` is only 134Kb,
and so the basic demonstration AndroLua application is just a 121Kb APK. Total
memory use is about 8 Meg and compares favourably with larger languages. Here Lua's
famous 'lack of batteries' is a virtue, since you can access practically all of the
Android APIs through LuaJava.

The command `alshell` opens a network connection to your device and can execute Lua
expressions, files and upload modules. You do not even need the ADK to experiment,
if your device is on a local wireless network.  However, you will need the ADK to
package your own AndroLua applications, and it's useful to access the documentation
off-line.

## LuaJava

LuaJava is a JNI binding to the native Lua 5.1 shared library. This has its
advantages and disadvantages; raw Lua speed is better, but you do pay for accessing
the JVM through JNI.

It provides a table `luajava` containing functions for binding Java classes and
instantiating Java objects. `bindClass` is passed the full qualified name of the
class (like `java.lang.math')

    > Math = luajava.bindClass 'java.lang.Math'
    > = Math:sin(1.2)
    0.93203908596723

Please note that all java methods, even static ones, require a colon!

To instantiate an object of a class, use `new`:

> ArrayList = luajava.bindClass 'java.util.ArrayList'
> a = luajava.new(ArrayList)
> a:add(10)
> a:add('one')
> = a:size()
2
> = a:get(0)
10
> = a:get(1)
one

LuaJava automatically boxes Lua types as Java objects, and unboxes them when they
are returned, even with tables.  So `a:get(1)` returns a Lua string.

Generally all Java `String` instances are converted into Lua strings; the exception
is if you _explicitly_ create a Java string:

    > String = luajava.bindClass 'java.lang.String'
    > s = luajava.new(String,'hello dolly')
    > = s
    hello dolly
    > = s:startsWith 'hello'
    true

These functions are tedious to type, and of course you can define local aliases for
them.  The `import` utility module goes a little further and provides a global
function `bind`:

    > require 'android.import'
    > HashMap = bind 'java.util.HashMap'
    > h = HashMap()
    > h:put('hello',10)
    > h:put(42,'bonzo')
    > = h:get(42)
    bonzo
    > = h:get('hello')
    10

The chief thing to note is that `bind` makes the class callable, so we no longer
have to explicitly use `new`.  If that constructor is passed a table, then an array
of that type is generated. A special case is if the type represents a number:

    > String = bind 'java.lang.String'
    > ss = String{'one','two','three'}
    > = ss
    [Ljava.lang.String;@41558458
    > Integer = bind 'java.lang.Integer'
    > ii = Integer{10,20,30}
    > = ii
    [I@41578230

So `ii` is an array of actual primitive ints!

It's still awkward to have to specify the full name of each class to be accessed. So
there is a way to make packages:

    > L = luajava.package 'java.lang'
    > = L.String
    class java.lang.String
    > = L.Boolean
    class java.lang.Boolean

`L` is a _smart table_ - if it can't find the field it uses `bind` to resolve the
class, and thereafter contains a direct reference. So it's an efficient idiom, and
generally you will not need to assign classses to their own variables.

`alshell` provides commands which begin with a dot:

    -- test.lua
    print 'hello world!'

    -- mod.lua
    mod = {}
    function mod.answer() return 42 end
    return mod

    > .l test.lua
    hello world!
    > .m mod
    wrote /data/data/sk.kottman.androlua/files/mod.lua
    > require 'mod'
    > = mod.answer()
    42

`.l` evaluates the Lua file directly, and `.m` writes the module to a location where
`require` can find it. (It will clear out the package.loaded table entry so that
subsequent `require` calls will pick up the new version.)

(A note on style: sometimes we have to be a little bad to do something good. In
interactive work, it's useful to break the rule that we don't create too many
globals, since it's only possible to access globals from the interactive prompt.)

The file `init.lua` is first loaded by `alshell`. It contains the following useful
definitions:

    PK = luajava.package
    W = PK 'android.widget'
    G = PK 'android.graphics'
    V = PK 'android.view'
    A = PK 'android'
    L = PK 'java.lang'
    U = PK 'java.util'

Once the session has started, you may explore the Android API interactively.
(`main.a` is a reference to the initial running `LuaActivity` instance):

    > r = main.a:getResources()
    > = r:getString(A.R_string.ok)
    OK
    > = r:getString(A.R_string.cancel)
    Cancel
    > = r:getString(A.R_string.dialog_alert_title)
    Attention


## Defining Activities in Lua

AndroLua provides a basic `LuaActivity` class derived from `Activity` which
implements many of the useful methods and forwards them to a Lua table; so there's
`onCreate`,`onPause`,'OnActivityResult'.

For instance, here is a layout-only version of the AndroLua main activity:


    -- raw.lua
    require 'android.import'

    local app = luajava.package 'sk.kottman.androlua'

    local raw = {}

    function raw.onCreate(a)
        a:setContentView(app.R_layout.main)
    end

    return raw

Note that `onCreate` receives a Java object of type `LuaActivity`; the base class
method has already been called.

Also note that the nested class `R.layout` is written with an underscore; this is
expanded to '$' when resolving the class. Since generally Java libraries don't use
underscores and Lua identifiers cannot contain '$', this is a reasonable hack.

Launching the activity uses the `.a` macro, which ends the current instance, uploads
the file and launches the activity:

    > .a raw
    ! MOD = raw
    ! if MOD and MOD.a then MOD.a:finish() end
    ! .m raw
    wrote /data/data/sk.kottman.androlua/files/raw.lua
    ! goapp 'raw'
    > starting Lua service

The beauty of this approach is that we can load and test an activity as fast as the
device can create it!

The best way to understand how the ball gets rolling in an AndroLua application is
to look at Main.java:

    package sk.kottman.androlua;

    import android.app.Activity;
    import android.os.Bundle;

    public class Main extends LuaActivity  {
        @Override
        public void onCreate(Bundle savedInstanceState) {
            CharSequence mod = getResources().getText(R.string.main_module);
            getIntent().putExtra("LUA_MODULE", mod);
            super.onCreate(savedInstanceState);

        }

    }

The key resource here is 'main_module', which is defined as 'main' in the project;
`LuaActivity` looks at the intent parameter 'LUA_MODULE' and does a `require` on it.

This 'raw' style is fine, but we can make things even better:

    easy = require 'android'.new()

    function easy.create(me)
        local w = me:wrap_widgets()
        me:set_content_view 'main'

        print(w.executeBtn, w.statusText, w.source)

        return true
    end

    return easy

Note that the entry point is now called `create`, and it receives a Lua table which
wraps the underlying activity object and provides a set of useful methods.
`set_content_view` is straightforward enough, but the application's package is
deduced for you.  `wrap_widgets` returns a lazy table which simplifies looking up a
layout's widgets by name - it looks up the id in `R.id` and calls `findViewById` for
you.

We don't have to use an XML layout, of course.  It's recommended practice because
(a) separating layout from code is generally a good idea and (b) it's a pain to
create layouts dynamically in Java.  (The second reason naturally feeds into the
first reason - anybody who needs convincing should look at Swing GUI code.)

The `android` module provides a few useful helpers when you wish to avoid XML - such
as prototyping a layout dynamically. Here is another version of the main AndroLua
activity, this time sans layout:

    -- easy.lua
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

        ...

        return layout
    end

    return easy

The `vbox` method generates a vertically oriented `LinearLayout`. It's passed a
table of widgets which may be followed by layout commands. The simplest is '+',
which gives the widget a weight.  So our edit view takes over most space, as
desired. Unlike `onCreate` the `create` function returns the actual view.

Lua is particularly satisfying once you get to handling events; in many cases a
first-class function is a better solution than the Java One True Way of creating Yet
Another Class.

The following code attaches a callback to the button's click event:

        me:on_click(executeBtn,function()
            local src = source:getText():toString()
            local ok,err = pcall(function()
                local res = service:evalLua(src,"tmp")
                status:append(res..'\n')
                status:append("Finished Successfully\n")
            end)
            if not ok then -- make a loonnng toast..
                me:toast(err,true)
            end
        end)

The global `service` is a reference to the local Lua service object created by
AndroLua, which is bound by `LuaActivity`.  (We could just as well have used
`loadstring` and avoided having to do some exception catching.)

The `toast` method is an example of turning a common Android one-liner into a
no-brainer.  There is only so much room in the average human mind for remembering
incantations (and we are all average at least _sometimes_)

## Alert Dialogs and Menus

A more flexible way of bothering the user is using `AlertDialog`. The `alert` method
provides a simplified interface.

  * title  Title of dialog, of form 'label[|drawable]' where 'drawable' is
'[android.']name'
  * kind either 'ok' or 'yesno' (for now)
  * message either a string, or a custom view
  * callback optional callback

So, for example:

    me:alert('Warning|android.btn_star','ok','Please redo!')

('android.btn_star' is short for the global `android.R.drawable.btn_star' resource.
Wihtout the 'android.' it picks up the drawable from your `R.drawable` class defined
in the application's resources.)

Another example is options and context menus. For instance, from the main AndroLua
module:

        local function launch (name)
            return function() me:luaActivity('examples.'..name) end
        end

        me:context_menu {
            view = ctrls.source;
            "list",launch 'list',
            "draw",launch 'draw',
            "icons",launch 'icons'
        }

`launch` is a classic factory function which generates callbacks. When you
long-press the source widget, the context menu will appear.

`options_menu` works in the same way, except that there is no need to specify a view
and you can also specify _icons_ in exactly the same way as for alerts. This is
activated either by the menu button on older versions of Android or the little menu
icon on the extreme bottom right.

## Custom List Views in Lua

Android has a number of list view adapters, which are convenient if you have your
data as Java objects and if you have the exact layout you need as a resource.

AndroLua has a `LuaListAdapter` class which is backed by a Lua table. In
`example/list.lua` (which shows the contents of the Lua global table), a custom view
is defined like this:

    local lv = me:luaListView(items,function (impl,position,view,parent)
        local item = items[position+1] -- position is zero-based...
        local txt1,txt2
        if not view then
            txt1 = me:textView{id = 1, size = '20sp'}
            txt2 = me:textView{id = 2, background = '#222222'}
            view = me:hbox{
                txt1,'+',
                me:hbox{
                    txt2,
                    {fill=false,width=100,gravity='CENTER'}
                }
            }
        else
            txt1 = view:findViewById(1)
            txt2 = view:findViewById(2)
        end
        txt1:setText(item.name)
        txt2:setText(item.type)
        txt1:setTextColor(item.type=='table' and tableclr or otherclr)
        return view
    end)

This does the usual optimization and reuses the previously created view.

With custom views, you can do practically anything. It's true that Android does not
really believe in the concept of 'selected item' as a highlighted thing, because the
selection gets lost in large lists. But it's straightforward to create a custom
selectable view - see the 'twolistview.lua' example.

Another kind of list view has expandable items. It's notorious for being a bitch to
setup if you're new to the game. Androlua defines a custom
`ExpandableListViewAdapter` which works on Lua tables:

    ela = require 'android'.new()

    -- the data is a list of entries, which are lists of children plus a corresponding
    -- 'group' field
    groups = {
        {group='Cars','Ford','Fiat'},
        {group='Planes','Boeing','Arbus'},
        {group='Phones','Apple','Nokia'},
    }

    function ela.create(me)
        local elv = me:luaExpandableListView (groups,{

            getGroupView = function (group,groupPos,expanded,view,parent)
                return me:hbox {me:textView{group,paddingLeft='35sp',size='30sp'}}
            end,

            getChildView = function  (child,groupPos,childPos,lastChild,view,parent)
                return me:textView{child,paddingLeft='50sp',size='20sp'}
            end

        })
        return elv
    end

    return ela

You override the two methods that generate the views; note that the signature is
slightly different and you are passed the child or group object as well as the
positions.

## Asynchronous Threading Support

Threading and Lua do not mix very well, since any particular Lua state is not
thread-safe. However, you can launch a new thread together with a new state. The
basic functionality is accessed from the global `service` object:

    service:createLuaThread(module_name,data,on_progress,on_post)

The code that's actually run in a different thread/state is referenced by _module
name_ - since it's tricky to copy functions across to different Lua states. The
`data` is any Java-compatible data - in particular, you may _not_ pass a Lua table.
But you can pass numbers, strings, Java arrays and other Java objects like hashmaps.

The module must return a function which is passed a reference to the thread object
and the data parameter, and returns the result. It's called in protected mode and
your callback can get the error if anything blew up.

This currently uses `AsyncTask`, and works in a similar way; your `on_progress`
handler will be called whenever the threaded code calls `setProgress` and `on_post`
will be called at the end with either the result, or `nil` plus the error message.

The `android.async` module has a few canned recipes - for instance
`async.read_http(request,false,callback)` will grab a HTTP request in the background
and pass the result as a string to the callback.  This is a common operation in
these days of web services and it's important not to hog the main GUI thread while
doing so (by default modern Android actually prohibits opening sockets on the main
thread.)  It runs the `android.http_async` module on a separate thread.


## Custom Views

A custom view is defined by a Lua table with an `onDraw` function, and optional
`onSizeChanged`,`onTouchEvent` and `onMeaure` overloads.  Thereafter things work
pretty much as expected.

`example/draw.lua` shows a Lua version of an Android [Java
example](http://bestsiteinthemultiverse.com/2008/11/android-graphics-example/)

## AndroLua Plotting Library (ALP)

This is a custom view which presents attractive data plots, inspired by the popular
[Flot](?) browser plot library.  (This is totally contained in the `android.plot`
package, so you may leave it out of your build if not needed.)

Here is a basic example that plots two normal distributions. The two series are the
array part of the table passed to the plot constructor, and the data is usually
specified as `xvalues` and `yvalues` (however _if_ `data` is used, it's assumed to
be in the form `{{x1,y1},{x2,y2}...}` as with Flot)

    local normal = require 'android'.new()
    local Plot = require 'android.plot'

    function normal.create (me)
        me.a:setTitle 'Androlua Plot Example'
        local pi = math.pi
        local spi = math.sqrt(2*pi)

        local xvalues = Plot.array(0,10,0.1) -- from 0 to 10, step 0.1

        local function norm_distrib (x,mu,sigma)
            local sfact = 2*sigma^2
            return math.exp(-(x-mu)^2/sfact)/(spi*sigma)
        end

        local plot = Plot.new {
            {
                label = 'μ = 5, σ = 1',
                xdata = xvalues,
                ydata = xvalues:map(norm_distrib,5,1),
            },
            {
                label = 'μ = 6, σ = 0.7',
                xdata = xvalues,
                ydata = xvalues:map(norm_distrib,6,0.7),
            },
        }


        return me:vbox{
            caption 'Plot Examples',
            plot:view(me)
        }


    end

    return normal

AndroLua has no problems here with UTF-8, although be aware that the `#` operator is
not to be trusted with multibyte encodings. For instance, the plot module explicitly
converts the labels to `String` and uses the `length` method to get the true length
in characters.

The `array` class provides a useful specialization of tables used as arrays of
numbers, and is also directly available as the `android.array` module. such arrays
are rather similar to Python lists in many ways; you can concatenate them, extract a
slice, and so forth. [ref](?)

The table passed to `Plot.new` may contain these fields:

  * theme - (default `{color='BLACK',background='WHITE'}`). May also have a `colors`
array which is used to pick the next series colour.
  * background  - background colour of view, or theme background
  * fill   - background colour of plot area, or theme background
  * color  - colour to use for drawing axes and text, or theme color
  * aspect_ratio - (default 1) Ratio between height and width of view
  * grid - whether to provide a grid
  * interactive - allow user to zoom with pinch and pan using drag
  * axes - if `false`, don't show axes.
  * xaxis,yaxis - optional control over axes; defined below
  * legend - optional control over legend
  * `annotations`, `markings` add extra annotations to the plot

Note: theme allows you to match with the theme used with the `android` package
functions.

The `xaxis` and `yaxis` tables may contain:

  * min, max - explicit data bounds. Usually worked out automatically.
  * label_size - default '12sp'
  * explicit_ticks - array of ticks. A tick can be a value, or `{value,label}`. May
have a field `format` which is either a string format (like '%5.1f') or a function
that converts a value to a string. (This defaults to `tostring`)
  * type - (default 'none') can be 'date' for using date-time values in seconds

For instance, in 'examples/plot.lua' explicit ticks are provided like so:

        xaxis = { -- we have our own ticks with labels
            ticks = {{0,'0'},{pi/2,'π/2'},{pi,'π'},{3*pi/2,'3π/2'},{2*pi,'2π'}},
        },

The `legend` field may be `false` to suppress it, a string giving the _corner_, or a
table containing:

   * `corner` one of 'LT','RT','LB' or 'RB'
   * `box` set to `false` to suppress the box
   * `fill` colour of the box
   * `across` (default `false`) arrange items across


The series follow as the array part of the table. Each series contains:

  * `label` label for legend. If not present, won't appear in legend
  * `tag` name for series when refering to it (rather than just by index)
  * `xvalues`, `yvalues` data for plot, _or_
  * `data` interleaved data as `{x,y}` points
  * `lines` (default 'solid') can be 'solid','steps','dash','dot' or 'dashdot'
  * `points` (default 'square') can be 'square' or 'circle'
  * `pointwidth` (default 10) size of points
  * `xunits` (default 'none') can be 'none' or 'msec' (useful for pulling in JSON
data where time is in milliseconds.)

Annotations (or 'markings', both words understood) allow you to mark up a plot. The
`annotations|markings` table can have (line/fill):

  * 'color',`lines` same meaning as for series (default colour is 60% opaque series
or plot colour)
  * `fill` explicit colour for filled annotations
  * `x`,`y` line annotations, either from x or y axis
  * `x1`,`x2` or `y1`,`y2' filled annotations
  * `series` reference to an existing series, either by index or tag. With line
annotations, this creates an intersection point with the series (only for x-axis
lines currently). For fill annotations, fills underneath the series.

And for text annotations:

  * `text`
  * `corner`
  * `anot`


## Performance Questions

LuaJava uses JNI to interface Lua with Java. Although calling C from Java is pretty
fast (accessing the C Lua API), calling Java methods from C is slower - effectively
a kind of reflection. Then there is the overhead of having to use reflection again
to resolve each method call dynamically.  There's some additional performance issues
to do with implementation details, which can be improved, but basically this means
that you should rather write code in Lua directly than use Java APIs.

This version of LuaJava has a number of optimizations aimed at reducing the amount
of garbage generated by reflection. For instance, caching whether a name is a field
or a method reduces the garbage generated significantly, because previously we
always tried to look up the name as a field first, and swallowed the exception if
not. (Exceptions turn out to be expensive in both time and memory, which is another
reason why they should be reserved for 'exceptional' conditions.)

A new feature is `luajava.method` which resolves a method, which can thereafter be
used without lookup overhead. This was very useful in the plot module, since the
graphics primitives get called a great deal (note that this function must be given
arguments of the desired type in order to resolve any overloads):

    -- cache the lineTo method!
    local lineTo = luajava.method(path,'lineTo',0.0,0.0)
    for i = 2,#xdata do
        lineTo(path,scalex(xdata[i]),scaley(ydata[i]))
    end

Again, the major speedup seen was due to calming down garabage collector activity
(which is a known bane of Android and other 'little Java' environments)

Another performance issue has to do with the _interesting_ memory management issues
you have with _two_ garbage-collected languages. References to java objects on the
Lua side are small objects, so the Lua GC has no way of knowing how important they
are, and hang on to references longer than we would wish. So manually calling
`collectgarbage` can be useful, but (as always) ensure that the Java objects aren't
referenced somewhere sneaky.

It's very straightforward to write your performance-critical code in Java, and
access it. The `android` module has a field `android.app` which is a package for
accessing your app's default package.

Because most of the overhead happens at the Lua/Java boundary, substituting LuaJIT
for regular Lua 5.1 would not give you much benefit, unless you were doing
computationally-intensive code in pure Lua without much interfacing with Android. An
interesting possibility opens up, however. LuaJIT can interface via FFI to the
platform's OpenGL faster than Java can, in fact comparable with C performance. So
partitioning a Lua Android application into the 'fast' (direct FFI with platform)
and 'slow' (LuaJava to Android Framework) parts can lead to a fast and yet very
flexible solution.

