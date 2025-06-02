Html :: #type,isa string;
Escaped :: #type,distinct string;

Html_Options :: struct {
    // Automatically escapes any expression that isn't the `Escaped` type.
    automatically_escape := true;

    // Replaces underscores in attributes, tags, and class names with a hyphen.
    replace_underscores_with_hyphens := true;
}

escape_html_string :: (str: string) -> Escaped {
    str1 := replace(str, "&",  "&amp;");
    str2 := replace(str1, "<",  "&lt;");
    str3 := replace(str2, ">",  "&gt;");
    str4 := replace(str3, "\"", "&quot;");
    str5 := replace(str4, "'",  "&#39;");

    free(str1);
    free(str2);
    free(str3);
    free(str4);

    return str5.(Escaped);
}

html :: (code: Code, $options := Html_Options.{}) -> Html #expand {
    STRINGS, CODE_EXPRS :: #run -> [] string, [] Code {
        builder: String_Builder;

        root := Compiler.compiler_get_nodes(code);
        lit := root.(*Compiler.Code_Literal);

        mew_check(root.kind == .LITERAL && lit.value_type == .STRUCT, root, "The html macro must start with a struct literal. For example, `html(.{ ... }).");

        struct_lit := lit.values.struct_literal_info;

        strings: [..] string;
        codes: [..] Code;

        for struct_lit.arguments {
            recurse_build_html_segments_from_code(*builder, it, *strings, *codes, options.replace_underscores_with_hyphens);
        }

        array_add(*strings, builder_to_string(*builder));

        return strings, codes;
    };

    #if STRINGS.count > 1 {
        #assert ((STRINGS.count - 1) == CODE_EXPRS.count) "The number of code expressions is larger than strings...?";
        builder: String_Builder;

        // Unfortunately, we have to manually unroll this loop to generate all the code...
        #insert -> string {
            gen_builder: String_Builder;
            for STRINGS {
                print_to_builder(*gen_builder, "append(*builder, STRINGS[%]);\n", it_index);
                if it_index < STRINGS.count-1 {
                    print_to_builder(*gen_builder, "value% := #insert,scope(code) CODE_EXPRS[%];\n", it_index, it_index);

                    pre_escaped := false;

                    if options.automatically_escape {
                        print_to_builder(*gen_builder, "#if type_of(value%) == Escaped || type_of(value%) == Html\n {", it_index, it_index);
                        print_to_builder(*gen_builder, "  append(*builder, value%.(string));\n", it_index);
                        print_to_builder(*gen_builder, "} else {\n");
                        print_to_builder(*gen_builder, "  escaped% := escape_html_string(tprint(\"\%\", value%));\n", it_index, it_index);
                        print_to_builder(*gen_builder, "  append(*builder, escaped%.(string));\n", it_index);
                        print_to_builder(*gen_builder, "}\n");
                    } else {
                        print_to_builder(*gen_builder, "print_to_builder(*builder, \"\%\", value%);\n", it_index);
                    }
                }
            }

            return builder_to_string(*gen_builder);
        }

        return builder_to_string(*builder).(Html);
    } else {
        return STRINGS[0].(Html);
    }
}

recurse_build_html_segments_from_code :: (
    builder: *String_Builder,
    root: *Compiler.Code_Node,
    strings: *[..] string,
    codes: *[..] Code,
    replace_underscores_with_hyphens: bool,
    closing := false,
    building_class := false
) {
    using Compiler;

    closing_string := ifx closing then "/" else "";

    if root.kind == {
    case .LITERAL;
        lit := root.(*Code_Literal);

        if lit.value_type == {
            case .STRING;
                print_to_builder(builder, lit.values._string);
                return;
            case .NUMBER;
                if lit.value_flags & .FLOAT {
                    print_to_builder(builder, "%", lit.values._float64);
                } else if lit.value_flags & .MINUS_SIGN {
                    print_to_builder(builder, "%", lit.values._s64);
                } else {
                    print_to_builder(builder, "%", lit.values._u64);
                }
                return;
            case .STRUCT;
                struct_lit := lit.values.struct_literal_info;

                expr := ifx struct_lit.type_expression != null then struct_lit.type_expression.type_valued_expression else null;

                if expr {
                    print_to_builder(builder, "<");
                    recurse_build_html_segments_from_code(builder, expr, strings, codes, replace_underscores_with_hyphens);
                    print_to_builder(builder, ">");
                }
                else {
                    // Assumed to be a div if there is no expression.
                    print_to_builder(builder, "<div>");
                }

                for struct_lit.arguments {
                    recurse_build_html_segments_from_code(builder, it, strings, codes, replace_underscores_with_hyphens);
                }

                if expr {
                    print_to_builder(builder, "<");
                    recurse_build_html_segments_from_code(builder, expr, strings, codes, replace_underscores_with_hyphens, closing = true);
                    print_to_builder(builder, ">");
                }
                else {
                    // Assumed to be a div if there is no expression.
                    print_to_builder(builder, "</div>");
                }
            case; mew_check(false, lit, "Value type not supported: %", lit.value_type);
        }

    case .IDENT;
        ident := root.(*Code_Ident);

        name := ident.name;

        if name == "DOCTYPE" {
            name = "!DOCTYPE html";
        }

        if !replace_underscores_with_hyphens {
            print_to_builder(builder, "%0%", closing_string, name);
        } else {
            print_to_builder(builder, "%", closing_string);
            print_name_replace_underscore(builder, name);
        }

    case .PROCEDURE_CALL;
        call := root.(*Code_Procedure_Call);
        expr := call.procedure_expression;
        if expr {
            recurse_build_html_segments_from_code(builder, expr, strings, codes, replace_underscores_with_hyphens, closing);
        }

        if !closing {
            for call.arguments_unsorted {
                mew_check(it.name != null, it.expression, "Attributes must have a name. For example, id=\"name\".");

                print_to_builder(builder, " ");
                recurse_build_html_segments_from_code(builder, it.name, strings, codes, replace_underscores_with_hyphens);
                print_to_builder(builder, "=\"");
                recurse_build_html_segments_from_code(builder, it.expression, strings, codes, replace_underscores_with_hyphens);
                print_to_builder(builder, "\"");
            }
        }

    case .BINARY_OPERATOR;
        bin_op := root.(*Code_Binary_Operator);

        mew_check(bin_op.operator_type == #char ".", bin_op, "Unsupported binary operator. Only \".\" is supported. Try quoting your class name if you need a special character.");
        // Left must be an ident

        if closing {
            recurse_build_html_segments_from_code(builder, bin_op.left, strings, codes, replace_underscores_with_hyphens, closing = true);
        } else {
            recurse_build_html_segments_from_code(builder, bin_op.left, strings, codes, replace_underscores_with_hyphens, building_class = true);

            // Add class to the left of the entire list of classes.
            print_to_builder(builder, " ");
            
            // Handles the case at the very end of this binary op chain (starting class attribute).
            if building_class && bin_op.left.kind == .IDENT {
                print_to_builder(builder, "class=\"");
            }

            recurse_build_html_segments_from_code(builder, bin_op.right, strings, codes, replace_underscores_with_hyphens, closing, building_class = true);

            // Handles the base case (ending class quote)
            if !building_class {
                print_to_builder(builder, "\"");
            }
        }
            
    case .DIRECTIVE_CODE;
        dir_code := root.(*Code_Directive_Code);
        array_add(strings, builder_to_string(builder));
        array_add(codes, compiler_get_code(dir_code.expression));

    case .UNARY_OPERATOR;
        op := root.(*Code_Unary_Operator);
        array_add(strings, builder_to_string(builder));
        array_add(codes, compiler_get_code(op.subexpression));

    case; mew_check(false, root, "Unsupported. Kind is %", root.kind);
    }

    return;
}

print_name_replace_underscore :: (builder: *String_Builder, str: string) {
    segments := split(str, "_");

    for segments {
        if it_index != 0 {
            print_to_builder(builder, "-");
        }

        print_to_builder(builder, "%", it);
    }
}

mew_check :: (arg: bool, node: *Compiler.Code_Node, message := "", args: .. Any) {
    if !arg {
        report_error(node, message);
    }
}

report_error :: (node: *Compiler.Code_Node, message := "", args: .. Any) {
    Compiler.compiler_report(tprint(message, args), Compiler.make_location(node));
}

#scope_module

#import "Basic";
#import "String";

Compiler :: #import "Compiler";
Program_Print :: #import "Program_Print";
