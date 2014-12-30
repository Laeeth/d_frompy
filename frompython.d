import std.stdio;
import std.file;
import std.string;
import std.array;
import std.conv;
import std.math;
import std.algorithm;

int lineNumber=0;

string docString = "\"\"\"";
int main(string[] args)
{
	bool mergeLines = true;
	string mergeBuf="";
	bool addbracket=false;
	bool commentState=false;
	bool rawString=false;
	int curIndent=0, prevIndent=0;
	int bracketstate=0;
	auto f=File("twisted.d","rb");
	auto lines=f.byLine();
	foreach(line;lines)
	{
		lineNumber++;
		if (strip(line).endsWith("\\") || strip(line).endsWith("("))
		{
			mergeLines=true;
			mergeBuf~=line;
			continue;
		}
		if (mergeLines)
		{
			line=mergeBuf~line;
			mergeLines=false;
		}
		line=replaceLen(line);
		line=replaceList(line);
		line=replacePrint(line);
		line=replace(line," elif "," else if ");
		line=replace(line," is not "," !is ");
		line=replace(line," + str(, "," ~ to!string(");
		line=replace(line,"(self, ","(");
		line=replace(line,"(self)","()");
		line=replace(line,"self.","this.");
		line=replace(line,"raise TypeError(","throw new Exception(");
		line=replace(line,"raise ValueError(","throw new Exception(");
		line=replace(line,"raise IllegalClientResponse(","throw new Exception(");
		line=replace(line,"#","//");
		line=replace(line,"True","true");
		line=replace(line,"False","foreachalse");
		line=replace(line," and ",") && (");
		line=replace(line," or ",") || (");
		curIndent=getIndent(line);
		if ((curIndent<prevIndent) && (bracketstate>0) && (commentState==false) && (rawString==false))
		{
			writefln("%s}",repeat(prevIndent-4," "));
			bracketstate--;
		}
		if (line.endsWith(":") && (commentState==false) && (rawString==false))
		{
			if (line.length>1)
				line=line[0..$-1];
			addbracket=true;
			bracketstate++;
		}
		while(indexOf(line,docString)!=-1)
		{
			if (commentState)
			{
				line=replaceOnce(line,docString,"*/");
				commentState=false;
			}
			else
			{
				line=replaceOnce(line,docString,"/*");
				commentState=true;
			}
		}
		if ((!addbracket) && (!strip(line).startsWith("def")) && !commentState && !isBlank(line) && !strip(line).endsWith("("))
		{
			line=addSemicolon(line);
		}
		if (strip(line).startsWith("if"))
			line=bracketizeExpression(line);
		else if (strip(line).startsWith("for"))
			line=convertFor(line);
		line=replaceAppend(line);
		line=replaceFormatString(line);
		line=replaceJoin(line);
		writeln(line);
		if (addbracket)
		{
			writefln("%s{",repeat(curIndent," "));
			addbracket=false;
		}
		prevIndent=curIndent;
	}
	curIndent=max(0,curIndent);
	foreach(i;0..bracketstate)
	{
		writefln("%s}",repeat(curIndent," "));
		if (curIndent>4)
			curIndent-=4;
	}
	writefln("*returning");
	return 0;
}


long lastIndexOfAny(char[]s, char[] tok)
{
	long i;
	i=s.length;
	while((i>1) && indexOf(tok,s[i-1])==-1)
		i--;
	if (indexOf(tok,s[i-1])!=-1)
		return i-1;
	else
		return -1;
}
char[] replaceFormatString(char[] s)
{
	long i=s.indexOf(" % (");
	long j=-1,k=-1;
	if (i!=-1)
	{
		j=lastIndexOfAny(s[0..i],['\'','\"']);
		if(j!=-1)
		{
			writefln("j=%s,%s",j,s[j]);
			k=lastIndexOf(s[0..i-j],s[j]);
			if (k!=-1)
				s=s[0..k]~"format(\""~s[k..j]~"\""~s[i+5..$];
		}
		else
		{
			j=lastIndexOf(s[0..i]," ");
			if(j!=-1)
			{
				k=lastIndexOf(s[0..j]," ");
				if (k!=-1)
				{					
					writefln("#%s - %s:%s,%s,%s",lineNumber, s,i,j,k);
					s=s[0..k+1]~"format(\""~s[k+1..j]~"\""~s[i+5..$];			
				}
			}
		}
	}
	return s;
}

char[] replaceJoin(char[] s)
{
	long i=s.indexOf(".join(");
	return s;
	if ((i!=-1) && (i+9<s.length))
	{
		auto j=s[i+9..$].lastIndexOf(")");
		if ((j!=-1) && ((i+9+j)<=s.length))
		{
			//writefln("%s,%s,%s",i,j,s);
			s=s[0..i]~"~="~s[i+8..i+9+j]~";";
		}
	}
	return s;
}

char[] replaceAppend(char[] s)
{
	long i=s.indexOf(".append(");
	if ((i!=-1) && (i+9<s.length))
	{
		auto j=s[i+9..$].lastIndexOf(")");
		if ((j!=-1) && ((i+9+j)<=s.length))
		{
			//writefln("%s,%s,%s",i,j,s);
			s=s[0..i]~"~="~s[i+8..i+9+j]~";";
		}
	}
	return s;
}
char[] replacePrint(char[] s)
{
	long i=s.indexOf("print ");
	if (i!=-1)
	{
		s=s[0..i]~"writefln("~s[i+6..$]~")";
	}
	return s;
}
char[] replaceLen(char[] s)
{
	long i,j;
	if ((i=s.indexOf("len("))!=-1)
	{
		j=indexOf(s[i+4..$],")");
		if ((j>-1)&&(i+4+j<s.length))
			s=s[0..i] ~ s[i+4..i+4+j]~".length"~s[i+5+j..$];
	}
	return s;
}

char[] replaceList(char[] s)
{
	long i;
	if ((i=s.indexOf(" = [];"))!=-1)
		s="string[] "~ repeat(getIndent(s)," ")~ strip(s[0..i]) ~";";
	return s;
}
char[] replaceOnce(char[] s, string tok, string tokrepl)
{
	auto i=indexOf(s,tok);
	if ((i==-1)||(i+tok.length>s.length))
		return s;
	return s[0..i]~ tokrepl~s[i+tok.length..$];
}

char[] bracketizeExpression(char[] s)
{
	auto i=indexOf(s,"if");
	if (i-5>(s.length))
		return s;
	auto ret=s[0..i+3] ~ "("~s[i+3..$]~")";
	if (ret[$-2..$]==":)")
		return ret[0..$-2]~"):";
	else
		return ret;
}
char[] addSemicolon(char[] s)
{
	auto i=indexOf(s,"//");
	if (i==-1)
		return s~";";
	if (strip(s).indexOf("//")<=1)
		return s;
	return s[0..i] ~ ";" ~ s[i..$];
}
bool isBlank(char[] s)
{
	return(strip(s).length==0);
}
int getIndent(char[] s)
{
	return getIndent(to!string(s));
}
int getIndent(string s)
{
	int i=0;
	while((s.length>=2) && ((s[0]==' ') || (s[0]=='\t')))
	{
		if (s[0]=='\t')
			i+=4;
		else
			i++;
		s=s[1..$];
	}
	return i;
}

string repeat( int i,string s)
{
	string ret="";
	while(i--)
	{
		ret~=s;
	}
	return ret;
}

char[]  convertFor(char[] s)
{
	auto k=getIndent(s);
	auto i=indexOf(s,"for ");
	if ((i+5)>s.length)
		return s;
	auto j=indexOf(s[i+4..$]," in ");
	if (j==-1)
		return s;
	auto ret="foreach("~s[i+4..i+4+j]~";"~s[i+4+j+4..$];
	if (ret[$-1]==':')
		return repeat(k," ")~ret[0..$-1]~")"~ret[$-1];
	else
		return repeat(k," ")~ret~")"; 
}