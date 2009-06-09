require File.dirname(__FILE__) + '/../lib/yard_types_parser'

def parse(types) 
  Parser.new(types).parse 
end

def parse_fail(types) 
  lambda { parse(types) }.should raise_error(SyntaxError) 
end

describe Type, '#to_s' do
  before { @t = Type.new(nil) }
  
  it "works for a class/module reference" do
    @t.name = "ClassModuleName"
    @t.to_s.should == "a ClassModuleName"
    @t.to_s(false).should == "ClassModuleNames"

    @t.name = "XYZ"
    @t.to_s.should == "a XYZ"
    @t.to_s(false).should == "XYZ's"
    
    @t.name = "Array"
    @t.to_s.should == "an Array"
    @t.to_s(false).should == "Arrays"
  end
  
  it "works for a method (ducktype)" do
    @t.name = "#mymethod"
    @t.to_s.should == "an object that responds to #mymethod"
    @t.to_s(false).should == "objects that respond to #mymethod"
  end
  
  it "works for a constant value" do
    ['false', 'true', 'nil', '4'].each do |name|
      @t.name = name
      @t.to_s.should == name
      @t.to_s(false).should == name
    end
  end
end

describe CollectionType, '#to_s' do
  before { @t = CollectionType.new("Array", nil) }
  
  it "can contain one item" do
    @t.types = [Type.new("Object")]
    @t.to_s.should == "an Array of (Objects)"
  end
  
  it "can contain more than one item" do
    @t.types = [Type.new("Object"), Type.new("String"), Type.new("Symbol")]
    @t.to_s.should == "an Array of (Objects, Strings or Symbols)"
  end
  
  it "can contain nested collections" do
    @t.types = [CollectionType.new("List", [Type.new("Object")])]
    @t.to_s.should == "an Array of (a List of (Objects))"
  end
end

describe FixedCollectionType, '#to_s' do
  before { @t = FixedCollectionType.new("Array", nil) }
  
  it "can contain one item" do
    @t.types = [Type.new("Object")]
    @t.to_s.should == "an Array containing (an Object)"
  end
  
  it "can contain more than one item" do
    @t.types = [Type.new("Object"), Type.new("String"), Type.new("Symbol")]
    @t.to_s.should == "an Array containing (an Object followed by a String followed by a Symbol)"
  end
  
  it "can contain nested collections" do
    @t.types = [FixedCollectionType.new("List", [Type.new("Object")])]
    @t.to_s.should == "an Array containing (a List containing (an Object))"
  end
end

describe FixedCollectionType, '#to_s' do
  before { @t = HashCollectionType.new("Hash", nil, nil) }
  
  it "can contain a single key type and value type" do
    @t.key_types = [Type.new("Object")]
    @t.value_types = [Type.new("Object")]
    @t.to_s.should == "a Hash with keys made of (Objects) and values of (Objects)"
  end
  
  it "can contain multiple key types" do
    @t.key_types = [Type.new("Key"), Type.new("String")]
    @t.value_types = [Type.new("Object")]
    @t.to_s.should == "a Hash with keys made of (Keys or Strings) and values of (Objects)"
  end
  
  it "can contain multiple value types" do
    @t.key_types = [Type.new("String")]
    @t.value_types = [Type.new("true"), Type.new("false")]
    @t.to_s.should == "a Hash with keys made of (Strings) and values of (true or false)"
  end
end


describe Parser, '#parse' do
  it "should parse a regular class name" do
    type = parse("MyClass")
    type.size.should == 1
    type.first.should be_a(Type)
    type.first.name.should == "MyClass"
  end
  
  it "should parse a path reference name" do
    type = parse("A::B")
    type.size.should == 1
    type.first.should be_a(Type)
    type.first.name.should == "A::B"
  end
  
  it "should parse a list of simple names" do
    type = parse("A, B::C, D, E")
    type.size.should == 4
    type[0].name.should == "A"
    type[1].name.should == "B::C"
    type[2].name.should == "D"
    type[3].name.should == "E"
  end
  
  it "should parse a collection type" do
    type = parse("MyList<String>")
    type.first.should be_a(CollectionType)
    type.first.types.size.should == 1
    type.first.name.should == "MyList"
    type.first.types.first.name.should == "String"
  end
  
  it "should allow a collection type without a name" do
    type = parse("<String>")
    type.first.name.should == "Array"
  end
  
  it "should allow a fixed collection type without a name" do
    type = parse("(String)")
    type.first.name.should == "Array"
  end

  it "should allow a hash collection type without a name" do
    type = parse("{K=>V}")
    type.first.name.should == "Hash"
  end
  
  it "should not accept two commas in a row" do
    parse_fail "A,,B"
  end
  
  it "should not accept two types not separated by a comma" do
    parse_fail "A B"
  end
  
  it "should not allow a comma without a following type" do
    parse_fail "A, "
  end
  
  it "should fail on any unrecognized character" do
    parse_fail "$"
  end
end

describe Parser, " // Integration" do
  it "should parse an arbitrarily nested collection type" do
    type = parse("Array<String, Array<Symbol, List(String, {K=>V})>>")
    result = "an Array of (Strings or an Array of (Symbols or a List containing 
      (a String followed by a Hash with keys made of (K's) and values of (V's))))"
    type.join.should == result.gsub(/\n/, '').squeeze(' ')
  end
  
  it "should parse various examples" do
    expect = {
      "Fixnum, Foo, Object, true" => "a Fixnum; a Foo; an Object; true",
      "#read" => "an object that responds to #read",
      "Array<String, Symbol, #read>" => "an Array of (Strings, Symbols or objects that respond to #read)",
      "Set<Number>" => "a Set of (Numbers)",
      "Array(String, Symbol)" => "an Array containing (a String followed by a Symbol)",
      "Hash{String => Symbol, Number}" => "a Hash with keys made of (Strings) and values of (Symbols or Numbers)",
      "Array<Foo, Bar>, List(String, Symbol, #to_s), {Foo, Bar => Symbol, Number}" => "an Array of (Foos or Bars); 
        a List containing (a String followed by a Symbol followed by an object that responds to #to_s); 
        a Hash with keys made of (Foos or Bars) and values of (Symbols or Numbers)"
    }
    expect.each do |input, expected|
      types = parse(input)
      types.join("; ").should == expected.gsub(/\n/, '').squeeze(' ')
    end
  end
end
