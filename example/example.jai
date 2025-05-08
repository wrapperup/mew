#import,file "../module.jai";

static :: link => tprint("somefancyhash/%", link);

my_cool_webpage :: (x: int, y: string) -> Html {
    return html(.{
        DOCTYPE,
        html,
        head.{
            script(type="text/javascript", src=~static("cool.js")).{},
        },
        body.{
            ~ifx x > 20 then html(.{
                h1.{ "X is greater than 20!" },
            }),

            h1.{ ~x },
            p.{ #code y },
        },
        div.test.more_awesome.than.four.four.four."special__class"(four="five", data_something="10").{},
    });
}

generate_html :: () {
    output := my_cool_webpage(30, "Hello!");
    print("%\n", output);
    write_entire_file("out.html", output);
}

COMPILE_TIME :: true;

#if COMPILE_TIME {
    #run,stallable {
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
