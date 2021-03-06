module dquick.system.window;

import dquick.system.guiApplication;
import dquick.maths.vector2f32;

public import dquick.script.dmlEngine;
public import dquick.item.declarativeItem;
public import dquick.item.graphicItem;
public import dquick.item.imageItem;
public import dquick.item.textItem;
public import dquick.item.borderImageItem;
public import dquick.item.mouseAreaItem;
public import dquick.item.scrollViewItem;
public import dquick.item.gridRepeaterItem;
public import dquick.maths.vector2s32;
public import dquick.renderer3D.openGL.renderer;
public import dquick.events.mouseEvent;

import dquick.utils.utils;

import core.runtime;

interface IWindow
{
public:
	bool			create();
	
	bool			wasCreated() const;
	bool			isMainWindow() const;

	void			setMainItem(GraphicItem item);	/// Window will take size of this item
	void			setMainItem(string filePath);	/// Window will take size of this item
	GraphicItem		mainItem();
	DMLEngine		dmlEngine();

	void			setPosition(Vector2s32 position);
	Vector2s32		position();

	void			setSize(Vector2s32 size);
	Vector2s32		size();

	void			setFullScreen(bool fullScreen);	/// It's recommanded to set the size with the screenResolution method before entering in FullScreen mode to avoid scaling
	bool			fullScreen();

	Vector2s32		screenResolution() const;

	void			show();

protected:
	void	close();	/// If call on main Window (first instancied) the application will exit. This method is only called by the destructor
	void	onPaint();
	void	onMouseEvent(MouseEvent mouseEvent);

	// TODO rajouter les flag maximized et minimized, comme ce sont des etats eclusifs, les mettre en enum avec le fullscreen
}

abstract class WindowBase : IWindow
{
public:
	this()
	{
		mScriptContext = new DMLEngine;
		mScriptContext.create();
		mScriptContext.addObjectBindingType!(DeclarativeItem, "Item")();
		mScriptContext.addObjectBindingType!(GraphicItem, "GraphicItem")();
		mScriptContext.addObjectBindingType!(ImageItem, "Image")();
		mScriptContext.addObjectBindingType!(TextItem, "Text")();
		mScriptContext.addObjectBindingType!(BorderImageItem, "BorderImage")();
		mScriptContext.addObjectBindingType!(MouseAreaItem, "MouseArea")();
		mScriptContext.addObjectBindingType!(ScrollViewItem, "ScrollView")();
		mScriptContext.addObjectBindingType!(GridRepeaterItem, "ColumnRepeater")();
		mScriptContext.addObjectBindingType!(GridRepeaterItem, "RowRepeater")();
		mScriptContext.addObjectBindingType!(GridRepeaterItem, "GridRepeater")();
	}

	~this()
	{
		debug destructorAssert(!wasCreated, "WindowBase.close method wasn't called.", mTrace);
	}

	bool	create()
	{
		debug mTrace = defaultTraceHandler(null);
		return true;
	}

	void	setMainItem(GraphicItem item)
	{
		mRootItem = item;
		/*
		GraphicItem	graphicItem = cast(GraphicItem)mRootItem;
		if (graphicItem)
		setSize(graphicItem.size);*/
	}

	void	setMainItem(string filePath)
	{
		mScriptContext.executeFile(filePath);

		mRootItem = mScriptContext.rootItem!GraphicItem();
		if (mRootItem is null)
			throw new Exception("There is no root item or it's not a GraphicItem");

		mRootItem.width = size().x;
		mRootItem.height = size().y;
	}

	GraphicItem	mainItem() {return mRootItem;}

	DMLEngine	dmlEngine() {return mScriptContext;}

	void	setSize(Vector2s32 newSize)
	{
		if (mRootItem)
		{
			mRootItem.width = newSize.x;
			mRootItem.height = newSize.y;
		}
	}

	void	close()
	{
		mRootItem.release();
		mRootItem = null;
		destroy(mScriptContext);
		mScriptContext = null;
		if (isMainWindow())
			GuiApplication.instance().quit();
	}

protected:
	void	onPaint()
	{
		if (mRootItem)
			mRootItem.paint(false);
	}

	void	onMouseEvent(MouseEvent mouseEvent)
	{
		if (mRootItem)
		{
			mRootItem.mouseEvent(mouseEvent);
		}
	}

private:
	DMLEngine	mScriptContext;
	GraphicItem	mRootItem;

	debug Throwable.TraceInfo	mTrace;
}
