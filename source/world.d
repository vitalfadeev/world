

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

    /*
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

        if (event.is_widgetable)
        if (event.is_gridable)
        foreach (widget; widgets.walk) {
            if (widget.grid.match (event.grid.loc)) {
                event.widget.widget = widget;
            }
        }

        return World.Event ();
    }
    */

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

    Widget*
    opOpAssign (string op : "~") (Widget* b) {
        widgets ~= b;
        return b;
    }
}

struct
Container {
    mixin ListAble!(typeof(this)) list;
    mixin WalkAble!(typeof(this)) walk;
    Grid.Widget grid;
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
        this.way          = way;
        this.balance      = balance;
        this.grid.min_loc = min_loc;
        this.grid.max_loc = max_loc;
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

    Container*
    opOpAssign (string op : "~") (Container* b) {
        if (this.l is null)
            this.l = b;
        else 
            link (this.r, b);

        this.r = b;

        return b;
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
    Grid.Widget grid;
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
        this.grid.min_loc = min_loc;
        this.grid.max_loc = max_loc;
    }

    this (Container* container, Len fix_len) {
        this.container = container;
        this.fix_len   = fix_len;        
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
ContAble (T) {
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
        b.l = a;
        a.r = b;
    }

    Widget*
    opOpAssign (string op : "~") (Widget* b) {
        if (this.l is null)
            this.l = b;
        else
            link (this.r, b);

        this.r = b;

        return b;
    }

    auto
    opCall () {
        return l.walk.walk (this.l);
    }
    auto
    opCall (Grid.Loc loc) {
        return l.walk.walk (this.l);
    }
    auto
    walk () {
        return l.walk.walk (this.l);
    }
}

struct
Grid {  // SIMD
    import loc;
    alias L   = ubyte;
    alias Loc = TLoc!L;
    alias Len = TLen!L;

    static
    auto
    between (Loc loc, Loc min_loc, Loc max_loc) {  // SIMD
        static foreach (i; 0..Loc.N)
        if (min_loc.xy[i] >= loc.xy[i] && max_loc.xy[i] <= loc.xy[i])
            return true;
        return false;
    }

    struct
    Widget {
        import loc;
        
        // Grid                // Сеточные координаты
        Loc        min_loc;    // начало, включая границу
        Loc        max_loc;    // конец, включая границу    

        bool
        match (Loc loc) {
            return Grid.between (loc, min_loc,max_loc);
        }
    }
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
