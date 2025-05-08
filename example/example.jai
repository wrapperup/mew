#import,file "../module.jai";

static :: link => tprint("somefancyhash/%", link);

my_cool_webpage :: (x: int, y: string) -> Html {
    return html(.{
        div.test.more.than.four.four.four(four="five") .{},
    });
}

generate_html :: () {
    output := my_cool_webpage(30, "Hello!");
    print("%\n", output);
    write_entire_file("out.html", output);
}

COMPILE_TIME :: true;

#if COMPILE_TIME {
    #run {
        Compiler.set_build_options_dc(.{do_output=false});
        generate_html();
    }

    Compiler :: #import "Compiler";
} else {
    main :: () {
        generate_html();
    }
}

#import "Basic";
#import "File";
