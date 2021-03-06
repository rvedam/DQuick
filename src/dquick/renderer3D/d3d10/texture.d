module dquick.renderer3D.d3d10.texture;

import dquick.renderer3D.d3d10.util;
import dquick.media.image;
import dquick.maths.vector2s32;
import dquick.utils.resourceManager;

import dquick.utils.utils;

import std.string;

import core.runtime;

import dquick.buildSettings;

static if (renderer == RendererMode.D3D10)
final class Texture : IResource
{
	mixin ResourceBase;

public:
	~this()
	{
//		debug destructorAssert(mId == mBadId, "Texture.release method wasn't called.", mTrace);
	}

	void	load(string filePath, Variant[] options = null)
	{
/*		debug mTrace = defaultTraceHandler(null);

		release();

		if (options.length == 0)
		{
			Image	image = resourceManager.getResource!Image(filePath);
			scope(exit) resourceManager.releaseResource(image);

			load(image);
		}
		else if (options.length == 1)
		{
			assert(options[0].type() == typeid(Image));
			load(options[0].get!Image());
		}
		else
			assert(false);

		mFilePath = filePath;*/
	}

	/// Replace the texture's image by the new one, format need to be the same (size, bytes per pixels, color encoding)
	void	update(Image image)
	{
/*		assert(image.size() == mSize);
		assert(image.nbBytesPerPixel() == mNbBytesPerPixels);
		// TODO check format (nbBytePerPixels) and color encoding

		checkgl!glEnable(GL_TEXTURE_2D);
		checkgl!glBindTexture(GL_TEXTURE_2D, mId);
		if (image.nbBytesPerPixel() == 3)
			checkgl!glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, mSize.x, mSize.y, GL_RGB, GL_UNSIGNED_BYTE, image.pixels());
		else if (image.nbBytesPerPixel() == 4)
			checkgl!glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, mSize.x, mSize.y, GL_RGBA, GL_UNSIGNED_BYTE, image.pixels());
		else
			throw new Exception("[Texture] Pixel format unsupported");*/
	}

	void	release()
	{
/*		if (mId != mBadId)
			checkgl!glDeleteTextures(1, &mId);
		mId = mBadId;
		mSize = Vector2s32(0, 0);*/
	}

	bool	isLoaded() {return false;/*mId != mBadId;*/}

	Vector2s32	size() {return mSize;}

//	GLuint	id() {return mId;}

private:
	void	load(Image image)
	{
/*		mSize.x = image.width;
		mSize.y = image.height;
		mNbBytesPerPixels = image.nbBytesPerPixel;

		checkgl!glEnable(GL_TEXTURE_2D);
		checkgl!glGenTextures(1, &mId);
		if (mId == mBadId)
			throw new Exception("[Texture] Unable to generate a texture");

		uint internalFormat;
		switch(image.nbBytesPerPixel)
		{
			case 1:
				internalFormat = GL_LUMINANCE;
				break;
			case 2:
				internalFormat = GL_LUMINANCE_ALPHA;
				break;
			case 3:
				internalFormat = GL_RGB;
				break;
			case 4:
				internalFormat = GL_RGBA;
				break;
			default:
				throw new Exception("[Texture] Pixel format unsupported");
		}

		checkgl!glBindTexture(GL_TEXTURE_2D, mId);
		checkgl!glTexImage2D(GL_TEXTURE_2D, 0, image.nbBytesPerPixel(), mSize.x, mSize.y, 0, internalFormat, GL_UNSIGNED_BYTE, image.pixels());

		checkgl!glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		checkgl!glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		//		checkgl!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		//		checkgl!glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

		mWeight = image.weight;*/
	}

	Vector2s32	mSize;
	ubyte		mNbBytesPerPixels = 0;

	debug Throwable.TraceInfo	mTrace;
}
