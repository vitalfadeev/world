import std.stdio : writeln;
import loc;


void
go () {
    // world
    // on world grid
    // on grid container
    // in container widget

    // init
    auto world = World (Len (ubyte.max,ubyte.max));  // ubyte.max = 255

    auto c1 = world.container (Container.Way.r, Container.Balance.l, Loc (0,0), Loc (L.max/3,1));
    auto c2 = world.container (Container.Way.r, Container.Balance.c, Loc (L.max/3,0), Loc (L.max/3,1));
    auto c3 = world.container (Container.Way.l, Container.Balance.r, Loc (L.max/3*2,0), Loc (L.max,1));

    auto a  = world.widget (c1, Len (1,1));
    auto b  = world.widget (c1, Len (1,1));
    auto c  = world.widget (c2, Len (1,1));
    auto d  = world.widget (c3, Len (1,1));
    auto e  = world.widget (c3, Len (1,1));

    // loop
    foreach (event; events)
        world.see (&event);
}

auto
events () {
    return [World.Event ()];
}

struct
World {
    // Grid
    Len        len;
    // Containers
    Containers containers;
    // Widgets
    Widgets    widgets;
    // Worlds
    World*     next;

    Container*
    container (Container.Way way, Container.Balance balance, Loc min_loc, Loc max_loc) {
        auto container = new Container (way,balance,min_loc,max_loc);
        containers ~= container;
        return container;
    }

    Widget*
    widget (Container* container, Len fix_len) {
        auto widget = new Widget (container,fix_len);
        widgets ~= widget;
        return widget;
    }

    Widget*
    widget (Loc min_loc, Loc max_loc) {
        auto widget = new Widget (min_loc, max_loc);
        widgets ~= widget;
        return widget;
    }

    auto
    see (World.Event* event) {
        // Grid able
        //   сетка матчит по сеточным координатам
        //     сеточные координаты лежат в event, туда попадают из конвертора
        //   pointer events
        //     motion
        //     button
        // Hot key
        //   key events
        // World events

        // key
        //   -> focused
        // pointer
        //   -> widgets


        // Grid able
        //   сначала верхнй мир
        //   затем нижний мир
        //     для решения "widget поверх мир"

        writeln (*event);
        if (event.is_widgetable)
        if (event.is_gridable)
        foreach (widget; widgets.walk) {
            if (widget.grid.match (event.grid.loc)) {
                event.widget.widget = widget;
            }
        }

        return World.Event ();
    }

    void
    rasterize (Len,FILL_FN) (Len window_len, FILL_FN fill) {
        // min_loc -> window coord
        version (NEVER) {
            auto kx = 1366 / L.max;  // 1024  // бижайшее цело степень двойки
            auto ky =  768 / L.max;  //  512  // бижайшее цело степень двойки
                                     //       // хвосты влево и вправо

             auto wind_x = near_2_int (window_len.x);
             auto grid_x = near_2_int (L.max);
             auto rest_x = wind_x - grid_x;  //хвосты влево и вправо
             auto padl_x = rest_x / 2; 

             // на сколько сдвигать биты ?
             auto wind_x_msb = msb (window_len.x);
             auto grid_x_msb = msb (L.max);

             int shift;
             int shift_left;
             if (wind_x_msb > grid_x_msb) {
                shift      = (wind_x_msb - grid_x_msb);
                shift_left = true;
            }
            else {
                shift      = (grid_x_msb - wind_x_msb);
                shift_left = false;
            }
        }

        foreach (_widget; widgets) {  // SIMD
            // fast vetsion
            auto min_loc = _widget.min_loc;
            auto max_loc = _widget.max_loc;
            if (shift_left) {
                auto windowed_min_x = min_loc.x << shift;
                auto windowed_min_y = min_loc.y << shift;
                auto windowed_max_x = max_loc.x << shift;
                auto windowed_max_y = max_loc.y << shift;

                fill (
                    padl_x + windowed_min_x, windowed_min_y,
                    padl_x + windowed_max_x, windowed_max_y);
            }
            else {
                auto windowed_min_x = min_loc.x >> shift;
                auto windowed_min_y = min_loc.y >> shift;
                auto windowed_max_x = max_loc.x >> shift;
                auto windowed_max_y = max_loc.y >> shift;

                fill (
                    padl_x + windowed_min_x, windowed_min_y,
                    padl_x + windowed_max_x, windowed_max_y);
            }
            // slow version
            version (NEVER) {
            auto min_loc = _widget.min_loc;
            auto max_loc = _widget.max_loc;
            auto windowed_min_x = min_loc.x * window_len.x / L.max;
            auto windowed_min_y = min_loc.y * window_len.y / L.max;
            auto windowed_max_x = max_loc.x * window_len.x / L.max;
            auto windowed_max_y = max_loc.y * window_len.y / L.max;
            }
        }
    }

    struct
    Event {
        Grid.Event      grid;
        Container.Event container;
        Widget.Event    widget;

        bool is_gridable;
        bool is_containerable;
        bool is_widgetable;

        // if (WidgetEvent) ...
        //bool opCast (T) () if (is (T == bool)) { return (widget !is null); }
    }
}

struct
Container {
    mixin ListAble!(typeof(this)) list;
    mixin WalkAble!(typeof(this)) walk;
    mixin GridAble!(typeof(this)) grid;
    mixin ContAble!(typeof(this)) cont;

    version (NEVER) {
    // Containers DList
    Container* l;
    Container* r;
    // Able
    bool       able = true;
    // Grid                // Сеточные координаты
    Loc        min_loc;    // начало, включая границу
    Loc        max_loc;    // конец, включая границу
    // Container
    Container* container;  // id контейнера = указатель
    Len        fix_len;    // fixed len, in gris-coord, 0 = auto
    }
    // Container algo
    Way        way     = Way.r;
    Balance    balance = Balance.l;


    this (Way way, Balance balance, Loc min_loc, Loc max_loc) {
        this.way     = way;
        this.balance = balance;
        this.min_loc = min_loc;
        this.max_loc = max_loc;
    }

    enum
    Way {
        r,
        l,
    }

    enum
    Balance {
        r,
        c,
        l,
    }

    struct
    Event {
        Container* container;

        // if (WidgetEvent) ...
        bool opCast (T) () if (is (T == bool)) { return (container !is null); }
    }
}

struct
Hbox_Container {
    Container _super;
    alias _super this;
}

struct
Containers {  // DList
    Container* l;
    Container* r;

    void
    opOpAssign (string op : "~") (Container* b) {
        if (this.l is null)
            this.l = b;
        else 
            link (this.r, b);

        this.r = b;
    }

    auto
    walk () {
        return l.walk.walk (this.l);
    }

    pragma (inline,true)
    static
    void
    link (Container* a, Container* b) {
        b.l = a;
        a.r = b;
    }
}

struct
Widget {
    mixin ListAble!(typeof(this)) list;
    mixin WalkAble!(typeof(this)) walk;
    mixin GridAble!(typeof(this)) grid;
    mixin ContAble!(typeof(this)) cont;
    //mixin EvntAble!(typeof(this)) evnt;
    
    version (NEVER) {
    // DList
    Widget*    l;
    Widget*    r;
    // Walk
    bool       walk_able = true;
    // Grid                // Сеточные координаты
    Loc        min_loc;    // начало, включая границу
    Loc        max_loc;    // конец, включая границу
    // Container           // Контейнерные кооринаты
    Container* container;  // id контейнера = указатель
    Len        fix_len;    // fixed len, in gris-coord, 0 = auto
    }

    this (Loc min_loc, Loc max_loc) {
        this.min_loc = min_loc;
        this.max_loc = max_loc;
    }

    this (Container* container, Len fix_len) {
        this.container = container;
        this.fix_len   = fix_len;        
    }

    struct
    Event {
        Widget* widget;

        // if (WidgetEvent) ...
        bool opCast (T) () if (is (T == bool)) { return (widget !is null); }
    }
}

mixin template
ListAble (T) {
    // Widgets DList
    T* l;
    T* r;

    auto
    walk (T* start) {
        return Walker (start);
    }

    struct
    Walker {
        T*   front;
        bool empty    () { return (front is null); }
        void popFront () { front = front.r; }
    }
}

mixin template
WalkAble (T) {
    // DList-based

    // Able
    bool able = true;

    auto
    walk (T* start) {
        return Walker (start);
    }

    struct
    Walker {
        T*    front;
              this      (T* front) { this.front = front; if (!empty && !_able) _find_able (); }
        bool  empty     () { return (front is null); }
        void  popFront  () { _find_able (); }
        void _find_able () { do front = front.r; while (!empty && !_able); }
        bool _able      () { return front.able; }
    }
}

mixin template
GridAble (T) {
    // Grid                // Сеточные координаты
    Loc        min_loc;    // начало, включая границу
    Loc        max_loc;    // конец, включая границу    

    bool
    match (Loc loc) {
        return Grid.between (loc, min_loc,max_loc);
    }
}

mixin template
ContAble (T) {
    // Container           // Контейнерные кооринаты
    Container* container;  // id контейнера = указатель
    Len        fix_len;    // fixed len, in gris-coord, 0 = auto    
}

mixin template
EvntAble (T) {
    EVENT_CB event_cb;
}
//alias EVENT_CB = void delegate (World.Event* event);  // struct {void* _this; void* _cb;}
alias EVENT_CB = void delegate (void* event);  // struct {void* _this; void* _cb;}

struct
Widgets {  // DList
    Widget* l;
    Widget* r;

    pragma (inline,true)
    static
    void
    link (Widget* a, Widget* b) {
        b.l = a;
        a.r = b;
    }

    void
    opOpAssign (string op : "~") (Widget* b) {
        if (this.l is null)
            this.l = b;
        else
            link (this.r, b);

        this.r = b;
    }

    auto
    walk () {
        return l.walk.walk (this.l);
    }
}

struct
Visitor {
    // Event
    World.Event* event;
    // 
    World*     current_world;
}

struct 
PointerEvent {
    //
}

struct
Grid {  // SIMD
    alias L   = ubyte;
    alias Loc = TLoc!L;
    alias Len = TLen!L;

    static
    auto
    between (Loc loc, Loc min_loc, Loc max_loc) {
        return false;
    }

    struct 
    Event {
        Loc loc;
    }
}

auto
to (T,A) (A a) {
    static if (is (T == Grid.Loc)) {
        return _loc_to_grid_loc (a);
    }
    else {
        import std.conv : std_conv_to = to;
        return a.std_conv_to!T;
    }
}

Grid.Loc
_loc_to_grid_loc (Loc) (Loc loc) {
    return Grid.Loc ();
}


auto
near_2_int (int a) {
    // найти старший бит
    // На современных процессорах (начиная с 486) время выполнения оптимизировано и составляет фиксированные 3+1 такты.
    //   mov ax,01011000b  ;AX=58h
    //   bsr bx,ax         ;BX=6, ZF=0    // 2**6
    //   xor ax,ax         ;AX=0
    //   bsr bx,ax         ;BX=?, ZF=1
    import core.bitop : bsr;
    return 2^^bsr (a);
}

auto
msb (int a) {
    // найти старший бит
    // На современных процессорах (начиная с 486) время выполнения оптимизировано и составляет фиксированные 3+1 такты.
    //   mov ax,01011000b  ;AX=58h
    //   bsr bx,ax         ;BX=6, ZF=0    // 2**6
    //   xor ax,ax         ;AX=0
    //   bsr bx,ax         ;BX=?, ZF=1
    import core.bitop : bsr;
    return bsr (a);
}


alias L   = Grid.L;
alias Loc = Grid.Loc;
alias Len = Grid.Len;



// world 
// 256x256
// ------------------------
//  1 ab  | 2  c   | 3  de
// ------------------------
// 3 containers
//   1
//   2
//   3
// widgets
//   a
//   b
//   c
//   d
//   e
//
// Widget a
//   l         = null
//   r         = &b
//   min_loc   = calculated_by_container
//   maz_loc   = calculated_by_container
//   able      = true
//   container = &container_1
//   fix_len   = Len (0,0)
//
// Container 1
//   l = null
//   r = &container_2
