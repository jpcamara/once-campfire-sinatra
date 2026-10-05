module Campfire
  THUMBNAIL_MAX_WIDTH = 1200
  THUMBNAIL_MAX_HEIGHT = 800
  THUMB_TRANSFORMATIONS = { "resize_to_limit" => [ THUMBNAIL_MAX_WIDTH, THUMBNAIL_MAX_HEIGHT ] }.freeze

  # Message attachments (Messages::AttachmentPresentation) and the attachments embedded in rich
  # text bodies (mentions, unfurled links).
  module Attachments
    VARIABLE_TYPES = %w[ image/png image/gif image/jpeg image/tiff image/bmp image/vnd.adobe.photoshop image/vnd.microsoft.icon image/webp image/avif image/heic image/heif ].freeze

    module_function

    def presentation(ctx, blob)
      runtime = ctx.runtime
      if variable?(blob) || blob.video?
        width, height = preview_dimensions(blob)
        if blob.video?
          poster = Storage.representation_path(runtime, blob, { "format" => "webp", "resize_to_limit" => [ THUMBNAIL_MAX_WIDTH, THUMBNAIL_MAX_HEIGHT ] })
          constrained(width, height, %(<video src="#{blob_path(runtime, blob)}" poster="#{poster}" controls="controls" preload="none" width="100%" height="100%" class="message__attachment"></video>))
        else
          thumb = Storage.representation_path(runtime, blob, thumb_transformations(blob))
          download = blob_path(runtime, blob, "attachment")
          img = %(<img width="#{width}" height="#{height}" class="message__attachment" loading="lazy" src="#{thumb}" />)
          link = %(<a class="flex" data-lightbox-target="image" data-action="lightbox#open" data-lightbox-url-value="#{download}" href="#{blob_path(runtime, blob)}">#{img}</a>)
          constrained(width, height, link)
        end
      else
        download = blob_path(runtime, blob, "attachment")
        name = HTML.h(blob.filename)
        %(<div class="flex-inline align-center gap-half"><img class="colorize--black" aria-hidden="true" src="#{Assets.path("common-file-text.svg")}" width="22" height="22" /><span>#{name}</span><a class="btn message__action-btn hide-in-ios-pwa" style="--width: auto;" href="#{download}"><img aria-hidden="true" src="#{Assets.path("download.svg")}" width="20" height="20" /><span class="for-screen-reader">Download #{name}</span></a><button class="btn message__action-btn" style="--width: auto;" data-controller="web-share" data-action="web-share#share" data-web-share-files-value="#{download}"><img aria-hidden="true" src="#{Assets.path("share.svg")}" width="20" height="20" /><span class="for-screen-reader">Share #{name}</span></button></div>)
      end
    end

    def variable?(blob)
      VARIABLE_TYPES.include?(blob.content_type)
    end

    # The thumb variant keeps the source format; Active Storage records it in the variation.
    def thumb_transformations(blob)
      { "format" => File.extname(blob.filename.to_s).delete_prefix(".").downcase.then { it.empty? ? "png" : it } }.merge(THUMB_TRANSFORMATIONS)
    end

    def blob_path(runtime, blob, disposition = nil)
      Storage.blob_path(runtime, blob, disposition: disposition)
    end

    def constrained(width, height, inner)
      if width && height
        %(<div class="max-inline-size center flex overflow-clip" style="width: #{width / 2}px; aspect-ratio: #{width / height.to_f};">#{inner}</div>)
      else
        %(<div class="max-inline-size center overflow-clip">#{inner}</div>)
      end
    end

    def preview_dimensions(blob)
      metadata = JSON.parse(blob.metadata.to_s) rescue {}
      width, height = metadata["width"], metadata["height"]
      if width.nil? || height.nil?
        [ nil, nil ]
      elsif width <= THUMBNAIL_MAX_WIDTH && height <= THUMBNAIL_MAX_HEIGHT
        [ width, height ]
      else
        scale = [ THUMBNAIL_MAX_WIDTH.to_f / width, THUMBNAIL_MAX_HEIGHT.to_f / height ].min
        [ width * scale, height * scale ]
      end
    end

    # ---- Attachments inside rich text

    def render(ctx, node)
      nil
    end

    def plain_text(ctx, node)
      node["caption"].to_s
    end

    def canonicalize(fragment)
      fragment
    end
  end

  module Sounds
    module_function

    def presentation(sound)
      inner = %(<button class="btn btn--plain" data-action="sound#play">🔊</button>) +
        (sound.image ? %(<img width="#{sound.image.width}" height="#{sound.image.height}" class="align--middle" src="#{Assets.path(sound.image.asset_path)}" />) : HTML.h(sound.text))
      %(<div class="sound" data-controller="sound" data-action="messages:play-&gt;sound#play" data-sound-url-value="#{Assets.path(sound.asset_path)}">#{inner}</div>)
    end
  end
end
