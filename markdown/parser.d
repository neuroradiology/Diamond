/**
* Copyright © DiamondMVC 2018
* License: MIT (https://github.com/DiamondMVC/Diamond/blob/master/LICENSE)
* Author: Jacob Jensen (bausshf)
*/
module diamond.markdown.parser;

import std.array : replace, split;
import std.string : format, strip, indexOf, isNumeric;
import std.conv : to;
import std.algorithm : canFind, startsWith;

import diamond.markdown.type;
import diamond.markdown.part;

/**
* Parses markdown to html.
* Params:
*   markdown = The markdown to parse.
* Returns:
*   A string equivalent to the parsed html from the markdwon.
*/
string parseToHtml(string markdown)
{
  string result;

  foreach (part; parse(markdown))
  {
    switch (part.type)
    {
      case MarkdownType.content:
      {
        result ~= part.content;
        break;
      }

      case MarkdownType.newline:
      {
        result ~= "<br>\r\n";
        break;
      }

      case MarkdownType.ulistStart:
      {
        result ~= "<ul>\r\n";
        break;
      }

      case MarkdownType.ulistEnd:
      {
        result ~= "</ul>\r\n";
        break;
      }

      case MarkdownType.olistStart:
      {
        result ~= "<ol>\r\n";
        break;
      }

      case MarkdownType.olistEnd:
      {
        result ~= "</ol>\r\n";
        break;
      }

      case MarkdownType.listItemStart:
      {
        result ~= "<li>\r\n";
        break;
      }

      case MarkdownType.listItemEnd:
      {
        result ~= "</li>\r\n";
        break;
      }

      case MarkdownType.link:
      {
        auto title = part.getMetadata("title");

        result ~= "<a href=\"%s\"%s>%s</a>".format
        (
          part.getMetadata("url"),
          title ? " title=\"" ~ title ~ "\"" : "",
          part.content
        );
        break;
      }

      case MarkdownType.image:
      {
        auto title = part.getMetadata("title");

        result ~= "<img src=\"%s\" alt=\"%s\"%s>".format
        (
          part.getMetadata("url"),
          part.content,
          title ? " title=\"" ~ title ~ "\"" : ""
        );
        break;
      }

      case MarkdownType.codeStart:
      {
        auto language = part.content;

        if (language)
        {
          result ~= "<pre class=\"highlight highlight-source-%s\"><code>\r\n".format(language);
        }
        else
        {
          result ~= "<pre><code>\r\n";
        }
        break;
      }

      case MarkdownType.codeEnd:
      {
        result ~= "</code></pre>\r\n";
        break;
      }

      case MarkdownType.contentWrapStart:
      {
        switch (part.content)
        {
          case "bold":
          {
            result ~= "<strong>";
            break;
          }

          case "italic":
          {
            result ~= "<em>";
            break;
          }

          case "underline":
          {
            result ~= "<span style=\"text-decoration: underline\">";
            break;
          }

          case "strike":
          {
            result ~= "<del>";
            break;
          }

          default: break;
        }
        break;
      }

      case MarkdownType.contentWrapEnd:
      {
        switch (part.content)
        {
          case "bold":
          {
            result ~= "</strong>";
            break;
          }

          case "italic":
          {
            result ~= "</em>";
            break;
          }

          case "underline":
          {
            result ~= "</span>";
            break;
          }

          case "strike":
          {
            result ~= "</del>";
            break;
          }

          default: break;
        }
        break;
      }

      case MarkdownType.header:
      {
        result ~= "<h%d>%s</h%d>\r\n".format(part.volume, part.content, part.volume);
        break;
      }

      default: break;
    }
  }

  return result ? result : "";
}

/**
* Parses markdown into parts.
* Params:
*   markdown = The markdown to parse.
* Returns:
*   An array of markdown parts.
*/
MarkdownPart[] parse(string markdown)
{
  const tab = cast(char)0x9;

  MarkdownPart[] parts;

  auto lines = markdown.replace("\r", "").split("\n");

  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool strike = false;

  size_t ulist = false;
  size_t olist = false;

  bool code = false;

  foreach (ref i; 0 .. lines.length)
  {
    auto lastLine = i > 0 ? lines[i - 1] : null;
    auto line = lines[i];
    auto nextLine = i < (lines.length - 1) ? lines[i + 1] : null;

    if (!line)
    {
      continue;
    }

    if (code)
    {
      if (line.strip() == "```")
      {
        parts ~= new MarkdownPart(MarkdownType.codeEnd);

        code = false;
      }
      else
      {
        auto part = new MarkdownPart(MarkdownType.content);
        part.content = line ~ "\r\n";

        parts ~= part;
      }

      continue;
    }

    void parseContent(string content)
    {
      MarkdownPart currentPart;
      foreach (ref j; 0 .. content.length)
      {
        auto lastChar = j > 0 ? content[j - 1] : cast(char)0;
        auto currentChar = content[j];
        auto nextChar = j < (content.length - 1) ? content[j + 1] : cast(char)0;

        if ((bold || (!bold && (lastChar == ' '  || lastChar == tab || j == 0))) && currentChar == '*' && nextChar == '*')
        {
          if (currentPart)
          {
            parts ~= currentPart;
            currentPart = null;
          }

          bold = !bold;

          auto part = new MarkdownPart(bold ? MarkdownType.contentWrapStart : MarkdownType.contentWrapEnd);
          part.content = "bold";

          parts ~= part;

          j++;
        }
        else if ((italic || (!italic && (lastChar == ' '  || lastChar == tab || j == 0))) && currentChar == '*')
        {
          if (currentPart)
          {
            parts ~= currentPart;
            currentPart = null;
          }

          italic = !italic;

          auto part = new MarkdownPart(italic ? MarkdownType.contentWrapStart : MarkdownType.contentWrapEnd);
          part.content = "italic";

          parts ~= part;
        }
        else if ((underline || (!underline && (lastChar == ' '  || lastChar == tab || j == 0))) && currentChar == '_')
        {
          if (currentPart)
          {
            parts ~= currentPart;
            currentPart = null;
          }

          underline = !underline;

          auto part = new MarkdownPart(underline ? MarkdownType.contentWrapStart : MarkdownType.contentWrapEnd);
          part.content = "underline";

          parts ~= part;
        }
        else if ((strike || (!strike && (lastChar == ' '  || lastChar == tab || j == 0))) && currentChar == '~')
        {
          if (currentPart)
          {
            parts ~= currentPart;
            currentPart = null;
          }

          strike = !strike;

          auto part = new MarkdownPart(strike ? MarkdownType.contentWrapStart : MarkdownType.contentWrapEnd);
          part.content = "strike";

          parts ~= part;
        }
        else
        {
          if (currentPart)
          {
            currentPart.content = currentPart.content ~ to!string(currentChar);
          }
          else
          {
            currentPart = new MarkdownPart(MarkdownType.content);
            currentPart.content = to!string(currentChar);
          }
        }
      }

      if (currentPart)
      {
        parts ~= currentPart;
      }
    }

    void parseUList(char ulistChar)
    {
      size_t indentation = line.indexOf(ulistChar) + 1;

      if (!ulist || ulist < indentation)
      {
        ulist++;

        parts ~= new MarkdownPart(MarkdownType.ulistStart);
      }
      else if (indentation < ulist)
      {
        parts ~= new MarkdownPart(MarkdownType.ulistEnd);
        ulist--;
      }

      parts ~= new MarkdownPart(MarkdownType.listItemStart);

      auto content = line[line.indexOf(ulistChar) + 1 .. $].strip();

      parseContent(content ~ " (" ~ to!string(ulist) ~ ")( " ~ to!string(indentation) ~ ")");

      parts ~= new MarkdownPart(MarkdownType.listItemEnd);
    }

    if (!line.length)
    {
      while (ulist)
      {
        parts ~= new MarkdownPart(MarkdownType.ulistEnd);
        ulist--;
      }

      while (olist)
      {
        parts ~= new MarkdownPart(MarkdownType.olistEnd);
        olist--;
      }

      parts ~= new MarkdownPart(MarkdownType.newline);
      continue;
    }

    // Header
    if (line[0] == '#')
    {
      auto hIndex = line.strip().indexOf(' ');
      auto headerStart = hIndex;

      if (hIndex == -1)
      {
        hIndex = line.strip().indexOf(tab);
        headerStart = hIndex;

        if (hIndex == -1)
        {
          hIndex = 0;
        }
      }

      if (hIndex > 6)
      {
        hIndex = 6;
      }

      if (hIndex)
      {
        auto part = new MarkdownPart(MarkdownType.header);
        part.content = line[headerStart .. $].strip();
        part.volume = hIndex;

        parts ~= part;
      }
    }
    // Header alt
    else if (nextLine.strip() == "======" || nextLine.strip() == "------")
    {
      auto part = new MarkdownPart(MarkdownType.header);
      part.content = line.strip();
      part.volume = nextLine.strip() == "======" ? 1 : 2;

      parts ~= part;

      i++;
    }
    else if (line.strip() == "```" || line.strip().startsWith("```"))
    {
      auto part = new MarkdownPart(MarkdownType.codeStart);

      if (line.strip().length > 3)
      {
        part.content = line[3 .. $];
      }

      parts ~= part;
      code = true;
      continue;
    }
    // unordered list
    else if (line.strip().length > 2 && (line.strip()[0] == '*' || line.strip()[0] == '+' || line.strip()[0] == '-') && line.strip()[1] == ' ')
    {
      parseUList(line.strip()[0]);
      continue; // Don't want <br> after </li>
    }
    // ordered list
    else if (line.strip().length > 3 && line.strip().indexOf('.') > 0 && line.strip()[0 .. line.strip().indexOf('.')].isNumeric)
    {
      size_t indentation = 1;

      foreach (c; line)
      {
        if (c != ' ' && c != tab)
        {
          break;
        }

        indentation++;
      }

      if (!olist || olist < indentation)
      {
        olist++;

        parts ~= new MarkdownPart(MarkdownType.olistStart);
      }
      else if (indentation < olist)
      {
        parts ~= new MarkdownPart(MarkdownType.olistEnd);
        olist--;
      }

      parts ~= new MarkdownPart(MarkdownType.listItemStart);

      auto content = line[line.indexOf('.') + 1 .. $].strip();

      parseContent(content);

      parts ~= new MarkdownPart(MarkdownType.listItemEnd);
      continue; // Don't want <br> after </li>
    }
    // link
    else if (line.strip()[0] == '[' && line.canFind(']') && line.canFind('(') && line.strip()[$-1] == ')')
    {
      auto link = line.strip();

      auto text = link[1 .. link.indexOf(']')];
      auto href = link[link.indexOf('(') + 1 .. $-1];

      auto firstHrefSpace = href.indexOf(' ');
      auto url = href[0 .. firstHrefSpace == -1 ? href.length : firstHrefSpace];
      string title;

      if (firstHrefSpace > 0)
      {
        title = href[firstHrefSpace + 1 .. $];
      }

      auto part = new MarkdownPart(MarkdownType.link);
      part.content = text;
      part.setMetadata("url", url.strip());

      if (title)
      {
        part.setMetadata("title", title.strip());
      }

      parts ~= part;
      continue; // We don't want <br> after <a></a>
    }
    // image
    else if (line.strip()[0] == '!' && line.strip()[1] == '[' && line.canFind(']') && line.canFind('(') && line.strip()[$-1] == ')')
    {
      auto image = line.strip();

      auto text = image[2 .. image.indexOf(']')];
      auto href = image[image.indexOf('(') + 1 .. $-1];

      const stringTerminator = cast(char)("\""[0]);

      auto stringTerminatorIndex = href.indexOf(stringTerminator);

      auto url = href[0 .. stringTerminatorIndex == -1 ? href.length : stringTerminatorIndex];
      string title;

      if (stringTerminatorIndex > 0 && image.strip()[$-2] == stringTerminator)
      {
        title = href[stringTerminatorIndex + 1 .. $-1];
      }

      auto part = new MarkdownPart(MarkdownType.image);
      part.content = text;
      part.setMetadata("url", url.strip());

      if (title)
      {
        part.setMetadata("title", title.strip());
      }

      parts ~= part;
      continue; // We don't want <br> after <img>
    }
    // Content
    else
    {
      parseContent(line.strip());
    }

    parts ~= new MarkdownPart(MarkdownType.newline);
  }

  return parts ? parts : [];
}
