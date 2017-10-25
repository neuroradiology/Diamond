/**
* Copyright © DiamondMVC 2016-2017
* License: MIT (https://github.com/DiamondMVC/Diamond/blob/master/LICENSE)
* Author: Jacob Jensen (bausshf)
*/
module diamond.views.viewparser;

import diamond.core.apptype;

static if (!isWebApi)
{
  import diamond.views.viewformats;
  import diamond.templates;

  import std.string : strip, format;
  import std.array : replace, split;

  /**
  * Parses the view parts into a view class.
  * Params:
  *   allParts = All the parsed parts of the view template.
  *   viewName = The name of the view.
  *   route =    The route of the view. (This is null if no route is specified or if using stand-alone)
  * Returns:
  *   A string equivalent to the generated view class.
  */
  string parseViewParts(Part[][string] allParts, string viewName, out string route)
  {
    route = null;

    string viewClassMembersGeneration = "";
    string viewConstructorGeneration = "";
    string viewModelGenerateGeneration = "";
    string viewCodeGeneration = "";
    string viewPlaceHolderGeneration = "";
    bool hasController;
    string layoutName = null;

    foreach (sectionName,parts; allParts)
    {
      if (sectionName && sectionName.length)
      {
        viewCodeGeneration ~= "case \"" ~ sectionName ~ "\":
        {
  ";
      }
      else
      {
        viewCodeGeneration ~= "default:
        {
";
      }

      foreach (part; parts)
      {
        if (!part.content || !part.content.strip().length)
        {
          continue;
        }

        import diamond.extensions;
        mixin ExtensionEmit!(ExtensionType.partParser, q{
          {{extensionEntry}}.parsePart(
            part,
            viewName,
            viewClassMembersGeneration, viewConstructorGeneration,
            viewModelGenerateGeneration,
            viewCodeGeneration
          );
        });
        emitExtension();

        switch (part.contentMode)
        {
          case ContentMode.appendContent:
          {
            viewCodeGeneration ~= parseAppendContent(part);
            break;
          }

          case ContentMode.mixinContent:
          {
            viewCodeGeneration ~= part.content;
            break;
          }

          case ContentMode.metaContent:
          {
            parseMetaContent(
              part,
              viewName,
              viewClassMembersGeneration, viewConstructorGeneration,
              viewModelGenerateGeneration, viewPlaceHolderGeneration,
              hasController,
              layoutName, route
            );
            break;
          }

          default : break;
        }
      }

      viewCodeGeneration ~= "break;
}
";
    }

    static if (isWebServer)
    {
      return viewClassFormat.format(
        viewName,
        viewClassMembersGeneration,
        viewConstructorGeneration,
        viewModelGenerateGeneration,
        hasController ? controllerHandleFormat : "",
        viewPlaceHolderGeneration,
        viewCodeGeneration,
        layoutName ? endLayoutFormat.format(layoutName) : endFormat
      );
    }
    else
    {
      return viewClassFormat.format(
        viewName,
        viewClassMembersGeneration,
        viewConstructorGeneration,
        viewModelGenerateGeneration,
        viewPlaceHolderGeneration,
        viewCodeGeneration,
        layoutName ? endLayoutFormat.format(layoutName) : endFormat
      );
    }
  }

  private:
  /**
  * Parses content that can be appended.
  * Params:
  *   part = The part to parse.
  * Returns:
  *   The appended result.
  */
  string parseAppendContent(Part part)
  {
    switch (part.name)
    {
      case "expressionValue":
      {
        return appendFormat.format(part.content);
      }

      case "escapedValue":
      {
        return escapedFormat.format("`" ~ part.content ~ "`");
      }

      case "expressionEscaped":
      {
        return escapedFormat.format(part.content);
      }

      default:
      {
        return appendFormat.format("`" ~ part.content ~ "`");
      }
    }
  }

  /**
  * Parses the meta content of a view.
  * Params:
  *   part =                        The part of the meta content.
  *   viewClassMembersGeneration =  The resulting string of the view's class members.
  *   viewConstructorGeneration =   The resulting string of the view's constructor.
  *   viewModelGenerateGeneration = The resulting string of the view's model-generate function.
  *   viewPlaceHolderGeneration =   The resulting string of the view's placeholder generation.
  *   hasController =               Boolean determining whether the view has a controller or not.
  *   layoutName =                  The name of the view's layout.
  *   route =                       The name of the view's route. (null if no route or if stand-alone.)
  */
  void parseMetaContent(Part part,
    string viewName,
    ref string viewClassMembersGeneration,
    ref string viewConstructorGeneration,
    ref string viewModelGenerateGeneration,
    ref string viewPlaceHolderGeneration,
    ref bool hasController,
    ref string layoutName,
    ref string route)
  {
    string[string] metaData;
    auto metaContent = part.content.replace("\r", "").split("---");

    foreach (entry; metaContent)
    {
      if (entry && entry.length)
      {
        import std.string : indexOf;

        auto keyIndex = entry.indexOf(':');
        auto key = entry[0 .. keyIndex].strip().replace("\n", "");

        metaData[key] = entry[keyIndex + 1 .. $].strip();
      }
    }

    foreach (key, value; metaData)
    {
      if (!value || !value.length)
      {
        continue;
      }

      switch (key)
      {
        case "placeHolders":
        {
          viewPlaceHolderGeneration = placeHolderFormat.format(value);
          break;
        }

        case "route":
        {
          import std.string : toLower;
          route = value.replace("\n", "").toLower();
          break;
        }

        case "model":
        {
          viewModelGenerateGeneration = modelGenerateFormat.format(value);
          viewClassMembersGeneration ~= modelMemberFormat.format(value);
          break;
        }

        static if (isWebServer)
        {
          case "controller":
          {
            hasController = true;
            viewClassMembersGeneration ~= controllerMemberFormat.format(value, viewName);
            viewConstructorGeneration ~= controllerConstructorFormat.format(value, viewName);
            break;
          }
        }

        case "layout":
        {
          layoutName = value.replace("\n", "");
          break;
        }

        default: break;
      }
    }
  }
}