// https://gist.github.com/markd2/5961219
#import "typestring.h"

static NSString *StructEncoding (char **typeScan);
 
// Remove all numbers from the string. Some type encoding strings include
// offsets and/or sizes, and they're often wrong. yay?
 
static NSString *ScrubNumbers (NSString *string) {
	NSCharacterSet *numbers = [NSCharacterSet decimalDigitCharacterSet];
	NSString *numberFree = [[string componentsSeparatedByCharactersInSet: numbers] componentsJoinedByString: @""];
	return numberFree;
} // ScrubNumbers
 
 
// Convert simple types.
// |typeScan| is scooted over to account for any consumed characters
static NSString *SimpleEncoding (char **typeScan) {
	typedef struct TypeMap {
		unichar discriminator;
		const char *name;
	} TypeMap;
	static TypeMap s_typeMap[] = {
		{ 'c', (const char *)"char" },
		{ 'i', (const char *)"int" },
		{ 's', (const char *)"short" },
		{ 'l', (const char *)"long" },
		{ 'q', (const char *)"long long" },
		{ 'C', (const char *)"unsigned char" },
		{ 'I', (const char *)"unsigned int" },
		{ 'S', (const char *)"unsigned short" },
		{ 'L', (const char *)"unsiged long" },
		{ 'Q', (const char *)"unsigned long long" },
		{ 'f', (const char *)"float" },
		{ 'd', (const char *)"double" },
		{ 'B', (const char *)"BOOL" },
		{ 'v', (const char *)"void" },
		{ '*', (const char *)"char *" },
		{ '#', (const char *)"class" },
		{ ':', (const char *)"selector" },
		{ '?', (const char *)"unknown" },
	};
 
	NSString *result = nil;
	 
	TypeMap *scan = s_typeMap;
	TypeMap *stop = scan + sizeof(s_typeMap) / sizeof(*s_typeMap);
	 
	while (scan < stop) {
		if (scan->discriminator == **typeScan) {
			result = @( scan->name );
			(*typeScan)++;
			break;
		}
		scan++;
	}
	 
	return result;
 
} // SimpleEncoding

 
// Process object/id/block types. Some type strings include the class name in "quotes"
// |typeScan| is scooted over to account for any consumed characters.
static NSString *ObjectEncoding (char **typeScan) {
	assert (**typeScan == '@');
	(*typeScan)++; // eat the '@'

	NSString *result = @"id";

	if (**typeScan == '\"') {
		(*typeScan)++; // eat the double-quote
		char *closeQuote = *typeScan;
		while (*closeQuote && *closeQuote != '\"')
			closeQuote++;
		*closeQuote = '\000';
		result = [NSString stringWithUTF8String: *typeScan];
		*closeQuote = '\"';
		*typeScan = closeQuote;
		return [NSString stringWithFormat:@"%@ *", result]; // heheh
	}
	if (**typeScan == '?') {
		result = @"(^block)";
		(*typeScan)++;
	}
	 
	return result;
 
} // ObjectEncoding

 
// Process pointer types. Recursive since pointers are people too.
// |typeScan| is scooted over to account for any consumed characters
static NSString *PointerEncoding (char **typeScan) {
	assert (**typeScan == '^');
	(*typeScan)++; // eat the '^'

	NSString *result = @"";

	if (**typeScan == '^') {
		result = PointerEncoding (typeScan);
	} else if (**typeScan == '{') {
		result = StructEncoding (typeScan);
	} else if (**typeScan == '@') {
		result = ObjectEncoding (typeScan);
	} else {
		result = SimpleEncoding (typeScan);
	}

	result = [result stringByAppendingString: @"*"];
	return result;

} // PointerEncoding
 
 
// Process structure types. Pull out the name of the first structure encountered
// and not worry about any embedded structures.
// |typeScan| is scooted over to account for any consumed characters
static NSString *StructEncoding (char **typeScan) {
	assert (**typeScan == '{');
	(*typeScan)++; // eat the '{'
	 
	NSString *result = @"";
	 
	// find the equal sign after the struct name
	char *equalSign = *typeScan;
	while (*equalSign && *equalSign != '=') {
		equalSign++;
	}
	*equalSign = '\000';
	result = [NSString stringWithUTF8String: *typeScan];
	*equalSign = '=';
	 
	// Eat the rest of the potentially nested structures.
	int openCount = 1;
	while (**typeScan && openCount) {
		if (**typeScan == '{') openCount++;
		if (**typeScan == '}') openCount--;
		(*typeScan)++;
	}
	 
	return result;
	 
} // StructEncoding
 
 
// Given an Objective-C type encoding string, return an array of human-readable
// strings that describe each of the types.
NSArray *ParseTypeString (NSString *rawTypeString) {
	NSString *typeString = ScrubNumbers (rawTypeString);
	char *base = strdup ([typeString UTF8String]);
	char *scan = base;
	 
	NSMutableArray *chunks = [NSMutableArray array];
	 
	while (*scan) {
		NSString *stuff = SimpleEncoding (&scan);
		 
		if (stuff) {
			[chunks addObject: stuff];
			continue;
		}
		 
		if (*scan == '@') {
			stuff = ObjectEncoding (&scan);
			[chunks addObject: stuff];
			continue;
		}
		 
		if (*scan == '^') {
			stuff = PointerEncoding (&scan);
			[chunks addObject: stuff];
			continue;
		}
		 
		if (*scan == '{') {
			stuff = StructEncoding (&scan);
			[chunks addObject: stuff];
			continue;
		}
		 
		// If we hit this, more work needs to be done.
		stuff = [NSString stringWithFormat: @"(that was unexpected: %c)", *scan];
		scan++;
	}
	 
	free (base);
	return chunks;
 
} // ParseTypeString
