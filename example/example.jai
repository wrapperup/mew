#import,file "../module.jai";

static :: link => tprint("somefancyhash/%", link);

my_component :: (title: string) -> Html {
    return html(.{
        h2.{ ~title },
        p.{ "My cool component." },
    });
}

my_cool_webpage :: (x: int, y: string) -> Html {
    return html(.{
        DOCTYPE,
        html,
        head.{
            script(type="text/javascript", src=~static("cool.js")).{},
        },
        body.{
            ~ifx x > 20 then html(.{
                h1.{ "Something happened?" },
            }),

            h1.{ ~x },
            p.{ ~y },

            ~my_component("Poggers"),
        },
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
