import std.stdio : writeln;


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
    foreach (event; events) {
        auto grid_event_loc = event.loc.to!(Grid.Loc);
        world.see (&event);
    }
}

auto
events () {
    return [GridEvent ()];
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

    void
    see (GridEvent* event) {
        // сначала верхнй мир
        // затем нижний мир
        //   для решения "widget поверх мир"
        auto visitor = Visitor (event,&this);

        writeln (*event);
        foreach (widget; widgets.walk) {
            writeln ("  ", *widget);
            widget.see (&visitor);
        }
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
}

struct
Container {
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
        return DListAble!(Container).walk (this.l);
    }

    pragma (inline,true)
    static
    void
    link (Container* a, Container* b) {
        b.l = a.r;
        a.r = b;
    }
}

struct
Widget {
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

    this (Loc min_loc, Loc max_loc) {
        this.min_loc = min_loc;
        this.max_loc = max_loc;
    }

    this (Container* container, Len fix_len) {
        this.container = container;
        this.fix_len   = fix_len;        
    }

    //
    void
    see (Visitor* visitor) {
        if (visitor.event.type == GridEvent.Type.POINTER) {
            if (Grid.between (visitor.event.loc,  min_loc, max_loc)) {
                // poiner over widget
            }
        }
    }
}

template
DListAble (T) {
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

template
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
        bool _able      () { return front.walk_able; }
    }
}

template
GridAble (T) {
    // Grid                // Сеточные координаты
    Loc        min_loc;    // начало, включая границу
    Loc        max_loc;    // конец, включая границу    
}

template
ContainerAble (T) {
    // Container           // Контейнерные кооринаты
    Container* container;  // id контейнера = указатель
    Len        fix_len;    // fixed len, in gris-coord, 0 = auto    
}

struct
Widgets {  // DList
    Widget* l;
    Widget* r;

    pragma (inline,true)
    static
    void
    link (Widget* a, Widget* b) {
        b.l = a.r;
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
        return WalkAble!(Widget).walk (this.l);
    }
}

struct
Visitor {
    // Event
    GridEvent* event;
    // 
    World*     current_world;
}

struct 
GridEvent {
    Type type;
    Loc  loc;
    union {
        PointerEvent pointer;
    }

    enum
    Type {
        _,
        POINTER,
    }
}

struct 
PointerEvent {
    //
}

struct
Grid {  // SIMD
    alias L   =  ubyte;
    alias Loc = .TLoc!L;
    alias Len = .TLen!L;

    static
    auto
    between (Loc loc, Loc min_loc, Loc max_loc) {
        return false;
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


struct
TLen (L) {  // SIMD
    L[2] xy;

    this (int x, int y) {
        xy[0] = x.to!L;
        xy[1] = y.to!L;
    }
}

struct
TLoc (L) {  // SIMD
    L[2] xy;

    auto x () { return xy[0]; }
    auto y () { return xy[1]; }

    this (int x, int y) {
        xy[0] = x.to!L;
        xy[1] = y.to!L;
    }
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
