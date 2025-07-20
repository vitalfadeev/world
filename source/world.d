

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
}

struct
Container {
    mixin ListAble list;
    mixin WalkAble walk;
    mixin GridAble grid;
    mixin ContAble cont;

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

mixin template
ContAble () {
    // Container           // Контейнерные кооринаты
    Container* container;  // id контейнера = указатель
    Len        fix_len;    // fixed len, in gris-coord, 0 = auto    
}

struct
Containers {  // DList
    Walk!Container s;
    alias s this;
}

struct
List (T) {
    T* l;  // start  // first
    T* r;  // end    // last

    T*
    opOpAssign (string op : "~") (T* b) {
        if (this.l is null)
            this.l = b;
        else 
            link (this.r, b);

        this.r = b;

        return b;
    }

    auto
    opSlice () {
        return Range (this.l);
    }

    pragma (inline,true)
    static
    void
    link (T* a, T* b) {
        b.l = a;
        a.r = b;
    }

    struct
    Range {
        T*   front;
        bool empty    () { return front is null; }
        void popFront () {        front = front.r; }
    }
}

mixin template
ListAble () {
    alias T = typeof(this);

    // Widgets DList
    T* l;
    T* r;
}


struct
Walk (T) {
    List!T s;
    alias  s this;

    auto
    opSlice () {
        return Filter!"front.walk.able" (s[]);
    }

    T*
    opOpAssign (string op : "~") (T* b) {
        s ~= b;
        return b;
    }
}

auto
Filter (string COND,R) (R range) {        
    struct
    _Filter (R) {
        R range;

              this      (R range) { this.range = range; _find_able (); }
        auto  front     () { return range.front; }
        auto  empty     () { return range.empty; }
        void  popFront  () {        range.popFront; _find_able (); }
        void _find_able () {        while (!empty && !mixin (COND)) range.popFront (); }
    }

    return _Filter!R (range);
}


mixin template
WalkAble () {
    // List-based
    alias T = typeof(this);

    // Able
    bool able = true;
}


struct
Widget {
    mixin ListAble list;
    mixin WalkAble walk;
    mixin GridAble grid;
    mixin ContAble cont;

    this (Loc min_loc, Loc max_loc) {
        this.grid.min_loc = min_loc;
        this.grid.max_loc = max_loc;
    }

    this (Container* container, Len fix_len) {
        this.cont.container = container;
        this.cont.fix_len   = fix_len;        
    }
}


struct
Widgets {  // DList
    Walk!Widget s;
    alias s this;

    auto
    opCall (Grid.Loc loc) {
        return s[];
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
}

mixin template
GridAble () {
    // Grid       // Сеточные координаты
    Grid.Loc min_loc;  // начало, включая границу
    Grid.Loc max_loc;  // конец, включая границу    

    bool
    match (Grid.Loc loc) {
        return Grid.between (loc, min_loc,max_loc);
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
