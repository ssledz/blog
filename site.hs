--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
import           Data.Monoid (mappend)
import           Hakyll
import           Text.Pandoc.SideNote (usingSideNotes)
import           Text.Pandoc.Definition
import           Text.Pandoc.Walk
import           Debug.Trace

--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "et-book/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    -- match (fromList ["about.rst", "contact.markdown"]) $ do
    --     route   $ setExtension "html"
    --     compile $ pandocCompiler
    --         >>= loadAndApplyTemplate "templates/default.html" defaultContext
    --         >>= relativizeUrls

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ customPandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts)
                 <> constField "title" "Archives"
                 <> constField "description" "The complete list of all posts."
                 <> defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls


    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts)
                 <> constField "description" "Blog home page."
                 <> defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler


--------------------------------------------------------------------------------
customPandocCompiler :: Compiler (Item String)
customPandocCompiler =
  pandocCompilerWithTransform
    defaultHakyllReaderOptions
    defaultHakyllWriterOptions
    ( removeFootnotesHeader
    . usingSideNotes
    -- . traceBlockWalk
    -- . traceInlineWalk
    )

-- | Remove empty footnotes header from the bottom of the page
removeFootnotesHeader :: Pandoc -> Pandoc
removeFootnotesHeader = walk $ \inline ->
  case inline of
    Header 1 ("footnotes", [], []) _ -> Null
    _                                -> inline

traceBlockWalk :: Pandoc -> Pandoc
traceBlockWalk = walk $ \(block :: Block) -> trace (show block <> "\n") block

traceInlineWalk :: Pandoc -> Pandoc
traceInlineWalk = walk $ \(inline :: Inline) -> trace (show inline <> "\n") inline

postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext
