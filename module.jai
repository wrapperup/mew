Html :: #type,isa string;
Escaped :: #type,distinct string;

Html_Options :: struct {
    // Escapes printed expressions.
    escape := true;
}

DEBUG_HTML_PARSING :: false;

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

        strings: [..] string;
        codes: [..] Code;

        recurse_build_html_segments_from_code(*builder, root, *strings, *codes);
        array_add(*strings, builder_to_string(*builder));

        return strings, codes;
    };

    #if STRINGS.count > 1 {
        assert((STRINGS.count - 1) == CODE_EXPRS.count, "The number of code expressions is larger than strings...?");
        builder: String_Builder;

        // Unfortunately, we have to manually unroll this loop to generate all the code...
        #insert -> string {
            gen_builder: String_Builder;
            for STRINGS {
                print_to_builder(*gen_builder, "append(*builder, STRINGS[%]);\n", it_index);
                if it_index < STRINGS.count-1 {
                    print_to_builder(*gen_builder, "value% := #insert,scope(code) CODE_EXPRS[%];\n", it_index, it_index);

                    pre_escaped := false;

                    if options.escape {
                        print_to_builder(*gen_builder, "#if type_of(value%) == Escaped || type_of(value%) == Html\n {", it_index, it_index);
                        print_to_builder(*gen_builder, "  append(*builder, value%.(string));\n", it_index);
                        print_to_builder(*gen_builder, "} else {\n");
                        print_to_builder(*gen_builder, "  escaped% := escape_html_string(tprint(\"%%\", value%));\n", it_index, it_index);
                        print_to_builder(*gen_builder, "  append(*builder, escaped%.(string));\n", it_index);
                        print_to_builder(*gen_builder, "}\n");
                    } else {
                        print_to_builder(*gen_builder, "print_to_builder(*builder, \"%%\", value%);\n", it_index);
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
    closing := false
) {
    using Compiler;

    closing_string := ifx closing then "/" else "";

    #if DEBUG_HTML_PARSING {
        log("Kind: %", root.kind);
    }

    if root.kind == {
    case .LITERAL;
        lit := root.(*Code_Literal);

        if lit.value_type == {
            case .STRING;
                print_to_builder(builder, lit.values._string);
                return;
            case .STRUCT;
                struct_lit := lit.values.struct_literal_info;

                expr := ifx struct_lit.type_expression != null then struct_lit.type_expression.type_valued_expression else null;

                if expr {
                    recurse_build_html_segments_from_code(builder, expr, strings, codes);
                }

                for struct_lit.arguments {
                    recurse_build_html_segments_from_code(builder, it, strings, codes);
                }

                if expr {
                    recurse_build_html_segments_from_code(builder, expr, strings, codes, closing = true);
                }
            case; assert(false, "Value type not supported: %", lit.value_type);
        }

    case .IDENT;
        ident := root.(*Code_Ident);

        name := ident.name;

        if name == "DOCTYPE" {
            name = "!DOCTYPE html";
        }

        print_to_builder(builder, "<%0%>", closing_string, name);

    case .PROCEDURE_CALL;
        call := root.(*Code_Procedure_Call);
        ident := call.procedure_expression.(*Code_Ident);
        print_to_builder(builder, "<%0%", closing_string, ident.name);

        if !closing {
            for call.arguments_unsorted {
                if it.name {
                    print_to_builder(builder, " %=\"", it.name.name);
                    recurse_build_html_segments_from_code(builder, it.expression, strings, codes);
                    print_to_builder(builder, "\"");
                } else {

                }
            }
        }

        print_to_builder(builder, ">");

    case .BINARY_OPERATOR;
        bin_op := root.(*Code_Binary_Operator);

        assert(bin_op.operator_type == xx Operator_Type.IS_EQUAL, "Not an equals sign.");


    case .DIRECTIVE_CODE;
        dir_code := root.(*Code_Directive_Code);
        array_add(strings, builder_to_string(builder));
        array_add(codes, compiler_get_code(dir_code.expression));

    case .UNARY_OPERATOR;
        op := root.(*Code_Unary_Operator);
        array_add(strings, builder_to_string(builder));
        array_add(codes, compiler_get_code(op.subexpression));

    case; assert(false, "Unsupported. Kind is %", root.kind);
    }

    return;
}

#scope_module

#import "Basic";
#import "String";

Compiler :: #import "Compiler";
Program_Print :: #import "Program_Print";
