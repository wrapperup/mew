# mew
Tiny JSX-Like HTML Templating library for Jai, inspired by [maud](https://github.com/lambda-fairy/maud)

## Usage

mew adds the `html()` macro. It takes in a syntax similar to pugjs/maud, and it outputs code to generate flattened HTML strings at runtime.
The syntax for HTML tags abuses Jai's struct expression grammar to implement the syntax. Here's what it looks like:

```jai
html(.{
    h1,
})
```
Will generate a lone `<h1>` without closing.

To generate opening/closing tags, use the struct syntax:
```jai
html(.{
    h1.{},
})
```
Will generate `<h1></h1>`.

Children can be added between the struct syntax. This can be a string and/or another tag:
```jai
html(.{
    h1.{ "Hello world!" },
    div.{ 
        p.{ "Lorem ipsum" }
    },
})
```
Generates `<h1>Hello world!</h1><div><p>Lorem ipsum</p></div>`

Attributes use the function call with named parameters syntax:
```jai
html(.{
    h1(class="header").{ "Heading #1" },
})
```
Generates `<h1 class="header">Heading #1</h1>`

Expressions can be interpolated into mew using `~` or `#code` (they work the same). The return value will be printed with `tprint()` internally. Expressions are also automatically escaped, and this is enforced at compile-time based on the return type of the expression. If your expression returns the `Escaped` type from mew, it will not be escaped.
```jai
a_function :: () -> Escaped {
    return "2 + 4 = ".(Escaped); // This string is safe, no need to escape it.
}

html(.{
    p.{
        ~a_function(),
        #code 2 + 4,
    },
})
```
Generates `<p>2 + 4 = 6</p>`

A shortcut for appending a list of classes also exists using the `.` operator. Class names can also be quoted if you need to use
non-ident characters. By default, underscores are replaced with hyphens. If you want to use other characters (including underscore), you can quote the class name to use any character.
```jai
html(.{
    p.large.font_heading."special__class".{
        "Hello!"
    },
})
```
Generates `<p class="large font-heading special__class">Hello!</p>`

## Example

```jai
#import "mew";

static :: (link: string) {
    return tprint("somefancyhash/%", link);
}

my_cool_website :: (x: int, y: string) -> Html {
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
    });
}

generate_html :: () {
    output := my_cool_website(30, "Hello!");
    print("%\n", output);
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
```
