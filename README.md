YARD Types Parser
=================

Parses YARD type declarations and translates them into plain English. A quick
example of a YARD type declaration is in the following parameter declaration:

    # @param [Array<String, Symbol>] arg takes an Array of Strings or Symbols
    def foo(arg)
    end
    
The parser will convert `Array<String, Symbol>` into the more readable:

    an Array of (Strings or Symbols)
    
You can quickly parse with:

    Parser.new("String, Symbol, false").parse.list_join 
    #=> "a String, a Symbol or false"
    
You can try this yourself live at [http://yard.soen.ca/types](http://yard.soen.ca/types)
with plenty more examples.