module dquick.renderer_2d.opengl.font;

import derelict.freetype.ft;

import dquick.algorithms.atlas;
import dquick.media.image;

import dquick.maths.vector2s32;
import dquick.maths.color;

import std.string;
import std.typecons;
import std.c.string;	// for memcpy

/**
* One Font per size
* kerning requested at runtime
*
*
**/

// TODO The font manager have to find fonts files in system folders
// The function FT_Open_Face may help to discover mFaces types (regular, italic, bold,...) registered in a font file
// http://www.freetype.org/freetype2/docs/reference/ft2-base_intermFace.html#FT_Open_Face
// http://forum.dlang.org/thread/kcqstrprmrzluvfoylqb@forum.dlang.org#post-fbojhpvgewysrrapfapw:40forum.dlang.org

// TODO migrate FT_Library to FontManager (if it share memory)

class FontManager
{
public:
	ref Font	getFont(string name, int size)
	{
		string	fontKey;
		Font*	font;

		fontKey = format("%s-%d", name.toStringz(), size);
		font = (fontKey in mFonts);
		if (font !is null)
			return *font;

		Font	newFont = new Font;

		newFont.load(name, size);
		mFonts[fontKey] = newFont;
		return *(fontKey in mFonts);
	}

	/// Use with caution, only next atlas creation will take the new size
	void	setAtlasSize(Vector2s32 size)
	{
		mAtlasSize = size;
	}

	Vector2s32	atlasSize()
	{
		return mAtlasSize;
	}

	Atlas	getAtlas(size_t index)
	{
		return mAtlases[index];
	}

private:
	Atlas	lastAtlas()
	{
		if (mAtlases.length)
			return mAtlases[$ - 1];
		return newAtlas();
	}

	Atlas	newAtlas()
	{
		mAtlases.length = mAtlases.length + 1;

		mAtlases[$ - 1] = new Atlas;
		mAtlases[$ - 1].create(mAtlasSize);

		return mAtlases[$ - 1];
	}

	Atlas[]			mAtlases;
	Font[string]	mFonts;
	Vector2s32		mAtlasSize = Vector2s32(512, 512);
}

FontManager	fontManager;

enum FontFamily
{
	Regular = 0x01,
	Bold = 0x02,
	Italic = 0x04
}

class Font
{
public:
	~this()
	{
		FT_Done_Face(mFace);
		FT_Done_FreeType(mLibrary);
	}

	Tuple!(Glyph, bool)	loadGlyph(uint charCode)
	{
		Glyph*	glyph;

		glyph = (charCode in mGlyphs);
		if (glyph !is null)
			return tuple(*glyph, true);

		// Load glyphs
		FT_Error		error;
		FT_Int32		flags = 0;
		FT_Glyph		ftGlyph;
		FT_GlyphSlot	ftGlyphSlot;
		FT_Bitmap		ftBitmap;
		FT_UInt			glyphIndex;
		size_t			depth;	// TODO replace x,y and width,height per Vector2s32
		Atlas.Region	region;
		Atlas			imageAtlas = fontManager.lastAtlas();

		depth  = 1;	// TODO do something better (because it impact the quality of rendering)

		glyphIndex = FT_Get_Char_Index(mFace, charCode);
		// WARNING: We use texture-atlas depth to guess if user wants
		//          LCD subpixel rendering

		if (mOutlineType > 0)
			flags |= FT_LOAD_NO_BITMAP;
		else
			flags |= FT_LOAD_RENDER;

		if (!mHinting)
			flags |= FT_LOAD_NO_HINTING | FT_LOAD_NO_AUTOHINT;
		else
			flags |= FT_LOAD_FORCE_AUTOHINT;

		if (depth == 3)
		{
			FT_Library_SetLcdFilter(mLibrary, FT_LcdFilter.FT_LCD_FILTER_LIGHT);
			flags |= FT_LOAD_TARGET_LCD;
			if (mFiltering)
				FT_Library_SetLcdFilterWeights(mLibrary, mLcdWeights.ptr);
		}
		error = FT_Load_Glyph(mFace, glyphIndex, flags);
		if (error)
			throw new Exception(format("Failed to load glyph. Error : %d", error));

		if (mOutlineType == 0)
		{
			ftGlyphSlot = mFace.glyph;
			ftBitmap = ftGlyphSlot.bitmap;
		}
		else
		{
			FT_Stroker		stroker;
			FT_BitmapGlyph	ftBitmapGlyph;

			error = FT_Stroker_New(mLibrary, &stroker);
			if (error)
				throw new Exception(format("Failed to create stroker. Error : %d", error));
			scope(exit) FT_Stroker_Done(stroker);
			FT_Stroker_Set(stroker,
						   cast(int)(mOutlineThickness * 64),
						   FT_Stroker_LineCap.FT_STROKER_LINECAP_ROUND,
						   FT_Stroker_LineJoin.FT_STROKER_LINEJOIN_ROUND,
						   0);
			error = FT_Get_Glyph(mFace.glyph, &ftGlyph);
			if (error)
				throw new Exception(format("Failed to get glyph. Error : %d", error));

			if (mOutlineType == 1)
				error = FT_Glyph_Stroke(&ftGlyph, stroker, 1);
			else if (mOutlineType == 2)
				error = FT_Glyph_StrokeBorder(&ftGlyph, stroker, 0, 1);
			else if (mOutlineType == 3)
				error = FT_Glyph_StrokeBorder(&ftGlyph, stroker, 1, 1);
			if (error)
				throw new Exception(format("Failed to use stroker. Error : %d", error));

			if (depth == 1)
			{
				error = FT_Glyph_To_Bitmap(&ftGlyph, FT_Render_Mode.FT_RENDER_MODE_NORMAL, null, 1);
				if (error)
					throw new Exception(format("Failed to convert glyph as bitmap. Error : %d", error));
			}
			else
			{
				error = FT_Glyph_To_Bitmap(&ftGlyph, FT_Render_Mode.FT_RENDER_MODE_LCD, null, 1);
				if (error)
					throw new Exception(format("Failed to convert glyph as bitmap. Error : %d", error));
			}
			ftBitmapGlyph = cast(FT_BitmapGlyph)ftGlyph;
			ftBitmap = ftBitmapGlyph.bitmap;
		}

		region = imageAtlas.allocateRegion(ftBitmap.width, ftBitmap.rows);
		if (region.x < 0)
		{
			throw new Exception("Texture atlas is full. Instanciate a new one isn't supported yet");	// TODO
			//			continue;
		}

		mGlyphs[charCode] = Glyph();
		glyph = (charCode in mGlyphs);

		with (*glyph)
		{
			atlasRegion			= region;
			outlineType			= mOutlineType;
			outlineThickness	= mOutlineThickness;
			offset.x			= mFace.glyph.bitmap_left;
			offset.y			= mFace.glyph.bitmap_top;
		}

		// Discard hinting to get advance
		FT_Load_Glyph(mFace, glyphIndex, FT_LOAD_RENDER | FT_LOAD_NO_HINTING);
		ftGlyphSlot = mFace.glyph;
		glyph.advance = Vector2s32(cast(int)(ftGlyphSlot.advance.x / 64.0), cast(int)(ftGlyphSlot.advance.y / 64.0));

		FT_Done_Glyph(ftGlyph);

		blitGlyph(ftBitmap, *glyph);

		return tuple(*glyph, false);
	}

	float	height()
	{
		return mHeight;
	}

	float	linegap()
	{
		return mLinegap;
	}

private:
	void	load(string filePath, int size)
	{
		FT_Error		error;
		size_t			hres = 64;
/*		FT_Matrix		matrix = {cast(int)((1.0 / hres) * 0x10000L),
		cast(int)((0.0) * 0x10000L),
		cast(int)((0.0) * 0x10000L),
		cast(int)((1.0) * 0x10000L)};*/

		error = FT_Init_FreeType(&mLibrary);
		if (error)
			throw new Exception(format("Failed to initialize FreeType mLibrary. Error : %d", error));

		error = FT_New_Face(mLibrary, filePath.toStringz(), 0, &mFace);
		if (error)
			throw new Exception(format("Failed to load mFace. Error : %d", error));

		error = FT_Select_Charmap(mFace, FT_Encoding.FT_ENCODING_UNICODE);
		if (error)
			throw new Exception(format("Failed to select charmap. Error : %d", error));

//		error = FT_Set_Char_Size(mFace, size * 64, 0, 72 * hres, 72);
		error = FT_Set_Pixel_Sizes(mFace, 0, size);
		if (error)
			throw new Exception(format("Failed to select charmap. Error : %d", error));

//		FT_Set_Transform(mFace, &matrix, null);
	}

	void	blitGlyph(const ref FT_Bitmap ftBitmap, ref Glyph glyph)
	{
		glyph.image = new Image;
		glyph.image.create("", glyph.atlasRegion.width, glyph.atlasRegion.height, 4);

		glyph.image.fill(Color(1.0f, 1.0f, 1.0f, 0.0f), Vector2s32(0, 0), Vector2s32(glyph.atlasRegion.width, glyph.atlasRegion.height));

		assert(glyph.atlasRegion.width == ftBitmap.width);
		assert(glyph.atlasRegion.height == ftBitmap.rows);

		size_t	depth;
		uint	x = 0;
		uint	y = 0;

		depth = glyph.image.nbBytesPerPixel;
		for (size_t i = 0; i < ftBitmap.width; i++)
			for (size_t j = 0; j < ftBitmap.rows; j++)
			{
				ubyte	color[4];

				color[0] = 255 - ftBitmap.buffer[j * ftBitmap.pitch + i];
				color[1] = 255 - ftBitmap.buffer[j * ftBitmap.pitch + i];
				color[2] = 255 - ftBitmap.buffer[j * ftBitmap.pitch + i];
				color[3] = ftBitmap.buffer[j * ftBitmap.pitch + i];
				memcpy(glyph.image.pixels + ((y + j) * ftBitmap.width + (x + i)) * depth, 
					   color.ptr,
					   color.sizeof);
			}
	}

	Glyph[uint]	mGlyphs;

	FT_Library	mLibrary;
	FT_Face		mFace;

    string	mFilename;	// TODO Set it

    float	mSize;		// TODO Set it
    int		mHinting;
    int		mOutlineType;	// (0 = None, 1 = line, 2 = inner, 3 = outer)
    float	mOutlineThickness;
    int		mFiltering;
    ubyte	mLcdWeights[5];

    float	mHeight;	// TODO Set it
    float	mLinegap;	// TODO Set it
    float	mAscender;	// TODO Set it
    float	mDescender;	// TODO Set it
    float	mUnderlinePosition;	// TODO Set it
    float	mUnderlineThickness;	// TODO Set it
}

// http://www.freetype.org/freetype2/docs/tutorial/step2.html
struct Glyph
{
    Vector2s32		offset;
    Vector2s32		advance;
    int				outlineType;
    float			outlineThickness;

	size_t			atlasIndex;
	Atlas.Region	atlasRegion;	// TODO check redundancy with width and height
	Image			image;
}

shared static this()
{
	fontManager = new FontManager;

	DerelictFT.load();
}

shared static ~this()
{
	DerelictFT.unload();
}

unittest
{
	Font	font;
	string	text;

	Image[]	images;

	font = fontManager.getFont("../data/samples/fonts/Vera.ttf", 36);
	text = "Iñtërnâtiônàlizætiøn";

	Image		textImage;
	Vector2s32	cursor;

	cursor.x = 0;
	cursor.y = /*cast(int)font.linegap*/ 36;
	textImage = new Image;
	textImage.create("", 500, 100, 4);
	textImage.fill(Color(1.0f, 1.0f, 1.0f, 0.0f), Vector2s32(0, 0), textImage.size());

	foreach (dchar charCode; text)
	{
		Tuple!(Glyph, bool)	glyphTuple;
		Glyph				glyph;
		bool				alreadyLoaded;

		glyphTuple = font.loadGlyph(charCode);
		glyph = glyphTuple[0];
		alreadyLoaded = glyphTuple[1];

		if (!alreadyLoaded)
		{
			// Allocate image if need
			while (glyph.atlasIndex >= images.length)
			{
				images ~= new Image;
				images[$ - 1].create(format("ImageAtlas-%d", images.length),
									 fontManager.getAtlas(images.length - 1).size().x,
									 fontManager.getAtlas(images.length - 1).size().y,
									 4);
				images[$ - 1].fill(Color(1.0f, 1.0f, 1.0f, 0.0f), Vector2s32(0, 0), images[$ - 1].size());
			}

			// Write glyph in image
			images[glyph.atlasIndex].blit(glyph.image,
										  Vector2s32(0, 0),
										  Vector2s32(glyph.atlasRegion.width, glyph.atlasRegion.height),
										  Vector2s32(glyph.atlasRegion.x, glyph.atlasRegion.y));
		}

		Vector2s32	pos;

		pos.x = glyph.offset.x;
		pos.y = -glyph.offset.y;
		textImage.blit(glyph.image,
					   Vector2s32(0, 0),
					   Vector2s32(glyph.atlasRegion.width, glyph.atlasRegion.height),
					   Vector2s32(cursor.x + pos.x, cursor.y + pos.y));
		cursor.x = cursor.x + glyph.advance.x;
	}

	textImage.save("../data/FontTestText.bmp");
}
