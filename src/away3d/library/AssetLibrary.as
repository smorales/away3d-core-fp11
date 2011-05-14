package away3d.library
{
	import away3d.events.AssetEvent;
	import away3d.events.LoaderEvent;
	import away3d.library.assets.IAsset;
	import away3d.library.assets.NamedAssetBase;
	import away3d.library.strategies.NamingStrategyBase;
	import away3d.library.strategies.NumSuffixNamingStrategy;
	import away3d.loaders.AssetLoader;
	import away3d.loaders.misc.AssetLoaderContext;
	import away3d.loaders.misc.AssetLoaderToken;
	import away3d.loaders.misc.SingleFileLoader;
	import away3d.loaders.parsers.ParserBase;
	
	import flash.events.EventDispatcher;
	import flash.net.URLRequest;

	public class AssetLibrary extends EventDispatcher
	{
		private static var _instances : Object = {};
			
		private var _loadingSessions : Vector.<AssetLoader>;
		
		private var _strategy : NamingStrategyBase;
		
		private var _assets : Vector.<IAsset>;
		private var _assetDictionary : Object;
		private var _assetDictDirty : Boolean;
		
		
		public static const NUM_SUFFIX : NamingStrategyBase = new NumSuffixNamingStrategy();
		
		
		public function AssetLibrary(se : SingletonEnforcer)
		{
			_assets = new Vector.<IAsset>;
			_assetDictionary = {};
			_loadingSessions = new Vector.<AssetLoader>;
			
			_strategy = NUM_SUFFIX;
		}
		
		
		
		/**
		 * Gets the singleton instance of the ResourceManager.
		 */
		public static function getInstance(key : String = 'default') : AssetLibrary
		{
			if (!_instances.hasOwnProperty(key))
				_instances[key] = new AssetLibrary(new SingletonEnforcer());
			
			return _instances[key];
		}
		
		
		public function get namingStrategy() : NamingStrategyBase
		{
			return _strategy;
		}
		public function set namingStrategy(val : NamingStrategyBase) : void
		{
			_strategy = val;
			if (!_strategy)
				throw new Error('namingStrategy must not be null. To ignore naming, use AssetLibrary.IGNORE');
		}
		
		
		public static function get namingStrategy() : NamingStrategyBase
		{
			return getInstance().namingStrategy;
		}
		public static function set namingStrategy(val : NamingStrategyBase) : void
		{
			getInstance().namingStrategy = val;
		}
		
		
		public function load(req : URLRequest, parser : ParserBase = null, context : AssetLoaderContext = null, namespace : String = null) : AssetLoaderToken
		{
			return loadResource(req, parser, context, namespace);
		}
		
		public static function load(req : URLRequest, parser : ParserBase = null, context : AssetLoaderContext = null, namespace : String = null) : AssetLoaderToken
		{
			return getInstance().load(req, parser, context, namespace);
		}
		
		
		
		public function parseData(data : *, parser : ParserBase = null, context : AssetLoaderContext = null, namespace : String = null) : AssetLoaderToken
		{
			return parseResource(data, parser, context, namespace);
		}
		
		public static function parseData(data : *, parser : ParserBase = null, context : AssetLoaderContext = null, namespace : String = null) : AssetLoaderToken
		{
			return getInstance().parseData(data, parser, context, namespace);
		}
		
		
		
		public function getAsset(name : String, namespace : String = null) : IAsset
		{
			var ns : String;
			var asset : IAsset;
			
			if (_assetDictDirty)
				rehashAssetDict();
			
			ns = namespace || NamedAssetBase.DEFAULT_NAMESPACE;
			if (!_assetDictionary.hasOwnProperty(ns))
				return null;
			
			return _assetDictionary[ns][name];
		}
		
		public static function getAsset(name : String, namespace : String = null) : IAsset
		{
			return getInstance().getAsset(name, namespace);
		}
		
		
		
		public static function enableParser(parserClass : Class) : void
		{
			SingleFileLoader.enableParser(parserClass);
		}
		
		public static function enableParsers(parserClasses : Vector.<Class>) : void
		{
			SingleFileLoader.enableParsers(parserClasses);
		}
		
		
		
		
		public static function addEventListener(type : String, listener : Function, useCapture : Boolean = false, priority : int = 0, useWeakReference : Boolean = false) : void		{			getInstance().addEventListener(type, listener, useCapture, priority, useWeakReference);		}								public static function removeEventListener(type : String, listener : Function, useCapture : Boolean = false) : void		{			getInstance().removeEventListener(type, listener,useCapture);		}								public static function hasEventListener(type : String) : Boolean		{			return getInstance().hasEventListener(type);		}								public static function willTrigger(type : String) : Boolean		{			return getInstance().willTrigger(type);		}
		
		
				
		/**
		 * Loads a yet unloaded resource file from the given url.
		 */
		private function loadResource(req : URLRequest, parser : ParserBase = null, context : AssetLoaderContext = null, namespace : String = null) : AssetLoaderToken
		{
			var loader : AssetLoader = new AssetLoader();
			_loadingSessions.push(loader);
			loader.addEventListener(AssetEvent.ASSET_COMPLETE, onAssetComplete);
			loader.addEventListener(away3d.events.LoaderEvent.RESOURCE_COMPLETE, onResourceRetrieved);
			loader.addEventListener(away3d.events.LoaderEvent.DEPENDENCY_COMPLETE, onDependencyRetrieved);
			loader.addEventListener(LoaderEvent.LOAD_ERROR, onDependencyRetrievingError);
			return loader.load(req, parser, context, namespace);
		}
		
		
		
		/**
		 * Retrieves an unloaded resource parsed from the given data.
		 * @param data The data to be parsed.
		 * @param id The id that will be assigned to the resource. This can later also be used by the getResource method.
		 * @param ignoreDependencies Indicates whether or not dependencies should be ignored or loaded.
		 * @param parser An optional parser object that will translate the data into a usable resource.
		 * @return A handle to the retrieved resource.
		 */
		private function parseResource(data : *, parser : ParserBase = null, context : AssetLoaderContext = null, namespace : String = null) : AssetLoaderToken
		{
			var loader : AssetLoader = new AssetLoader();
			_loadingSessions.push(loader);
			loader.addEventListener(AssetEvent.ASSET_COMPLETE, onAssetComplete);
			loader.addEventListener(away3d.events.LoaderEvent.RESOURCE_COMPLETE, onResourceRetrieved);
			loader.addEventListener(away3d.events.LoaderEvent.DEPENDENCY_COMPLETE, onDependencyRetrieved);
			return loader.parseData(data, '', parser, context, namespace);
		}
		
		
		
		private function addAsset(asset : IAsset) : void
		{
			var old : IAsset;
			
			_assets.push(asset);
			
			old = getAsset(asset.name, asset.assetNamespace);
			
			// No collission, just add it
			if (!old) {
				if (!_assetDictionary.hasOwnProperty(asset.assetNamespace))
					_assetDictionary[asset.assetNamespace] = {};
				
				_assetDictionary[asset.assetNamespace][asset.name] = asset;
			}
			
			// Treat this as if it was a rename (since it effectively also means that a
			// new name has been introduced).
			_assetDictDirty = _strategy.handleRename(asset, old, _assetDictionary, NamingStrategyBase.PREFER_NEW);
			
			
			asset.addEventListener(AssetEvent.ASSET_RENAME, onAssetRename);
		}
		
		
		private function rehashAssetDict() : void
		{
			var asset : IAsset;
			
			_assetDictionary = {};
			
			_assets.fixed = true;
			for each (asset in _assets) {
				if (!_assetDictionary.hasOwnProperty(asset.assetNamespace))
					_assetDictionary[asset.assetNamespace] = {};
				
				_assetDictionary[asset.assetNamespace][asset.name] = asset;
			}
			_assets.fixed = false;
			
			_assetDictDirty = false;
		}
		
		
		/**
		 * Called when a dependency was retrieved.
		 */
		private function onDependencyRetrieved(event : away3d.events.LoaderEvent) : void
		{
			if (hasEventListener(away3d.events.LoaderEvent.DEPENDENCY_COMPLETE))
				dispatchEvent(event);
		}
		
		/**
		 * Called when a an error occurs during dependency retrieving.
		 */
		private function onDependencyRetrievingError(event : LoaderEvent) : void
		{
			var ext:String = event.url.substring(event.url.length-4, event.url.length).toLowerCase();
			if (hasEventListener(LoaderEvent.LOAD_ERROR)){
				dispatchEvent(event);
			}
			
			else throw new Error(event.message);
		}
		
		private function onAssetComplete(event : AssetEvent) : void
		{
			addAsset(event.asset);
			dispatchEvent(event.clone());
		}
		
		/**
		 * Called when the resource and all of its dependencies was retrieved.
		 */
		private function onResourceRetrieved(event : away3d.events.LoaderEvent) : void
		{
			var session : AssetLoader = AssetLoader(event.target);
			
			var index : int = _loadingSessions.indexOf(session);
			session.removeEventListener(LoaderEvent.LOAD_ERROR, onDependencyRetrievingError);
			session.removeEventListener(away3d.events.LoaderEvent.RESOURCE_COMPLETE, onResourceRetrieved);
			session.removeEventListener(away3d.events.LoaderEvent.DEPENDENCY_COMPLETE, onDependencyRetrieved);
			session.removeEventListener(away3d.events.LoaderEvent.DEPENDENCY_ERROR, onDependencyRetrievingError);
			session.removeEventListener(AssetEvent.ASSET_COMPLETE, onAssetComplete);
			
			_loadingSessions.splice(index, 1);
			
			/*
			if(session.handle){
				dispatchEvent(event);
			}else{
				onResourceError((session is IResource)? IResource(session) : null);
			}
			*/
			
			dispatchEvent(event.clone());
		}
		
		/**
		 * Called when unespected error occurs
		 */
		private function onResourceError() : void
		{
			var msg:String = "Unexpected parser error";
			if(hasEventListener(away3d.events.LoaderEvent.DEPENDENCY_ERROR)){
				var re:away3d.events.LoaderEvent = new away3d.events.LoaderEvent(away3d.events.LoaderEvent.DEPENDENCY_ERROR, "");
				dispatchEvent(re);
			} else{
				throw new Error(msg);
			}
		}
		
		
		private function onAssetRename(ev : AssetEvent) : void
		{
			var asset : IAsset = IAsset(ev.currentTarget);
			/*
			var old : IAsset = getAsset(asset.assetNamespace, asset.name);
			_assetDictDirty ||= _strategy.handleRename(asset, old, _assetDictionary, NamingStrategyBase.PREFER_NEW);
			*/
			if (!_assetDictionary.hasOwnProperty(asset.assetNamespace))
				_assetDictionary[asset.assetNamespace] = {};
			_assetDictionary[asset.assetNamespace][asset.name] = asset;
		}
	}
}

// singleton enforcer
class SingletonEnforcer
{
}
