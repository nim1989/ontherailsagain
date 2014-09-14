# encoding: utf-8
class Article < ActiveRecord::Base
  include ArticlesHelper
  has_and_belongs_to_many :authors
  has_and_belongs_to_many :tags

  validates :authors, :associated => true
  validates :tags   , :associated => true

  # The link is the title without spaces (blank) neither accents. It is used for URLs.
  # It has to be unique
  validates :title, :link, :uniqueness => true
  validates :title, :introduction, :content, :link, :presence => true

  before_validation :generate_link
  before_save :generate_table_of_content
  before_save :generate_anchor_links

  scope :active, -> { where(activated: true) }

  # For pagination gem
  self.per_page = 5

  # Permalink
  def permalink
    "http://ontherailsagain.com/articles/#{self.link}"
  end

  def to_param
    self.link
  end
  # Generate the table of content in a nested list composed of all headers of the article
  # The method is REALLY ugly because I can't access matched string in the gsub...
  # Don't even try to understand it.
  def generate_table_of_content
    table_of_content_string = '<ul class="nav">'
    first = true
    oldH = 1
    h = ''
    index = 1
    self.content.gsub(/<h[0-9][^>]*>[^<]*<\/h[0-9]>/m) do |match|
      h     = match[2].chr
      title = match.sub(/<h[0-9][^>]*>/m, '').sub(/<\/h[0-9]>/m, '')
      link  = "#{escape_characters(title)}-#{index.to_s}"
      nb_ul = 1
      if !first
        case (h.to_i - oldH)
          when 1
            table_of_content_string += '<ul>'
          when 0
            table_of_content_string += '</li>'
          else
            table_of_content_string += '</li>'
            (h.to_i - oldH).abs.times do
              table_of_content_string += '</ul></li>'
            end
        end
      end
      table_of_content_string += "<li><a href='##{link}'>#{title}</a>"
      oldH = h.to_i
      first = false
      index = index + 1
    end
    table_of_content_string += '</li>'
    (oldH - 1).abs.times do
      table_of_content_string += '</ul></li>'
    end
    table_of_content_string += "</ul>"
    self.table_of_content = table_of_content_string
  end


  # Add an id to all the headers
  # Ids are generating in the same way that URLs are.
  def generate_anchor_links
    index = 1
    self.content = self.content.gsub(/<h[0-9]>[^<]*<\/h[0-9]>/m) do |match|
      h     = match[2].chr # Number of the header
      title = match.sub(/<h[0-9]>/m, "").sub(/<\/h[0-9]>/m, "")
      link  = "#{escape_characters(title)}-#{index.to_s}"
      index = index + 1
      "<h#{h} id='#{link}'>#{title}</h#{h}>"
    end
  end

  # Is called before validation of the article when it is created
  # Generate a link for an article based on its title
  def generate_link
    self.link = escape_characters self.title
    self.bitly_url = BITLY.shorten(self.permalink).bitly_url
  end

  def activate_article
    self.activated = true
  end

  def desactivate
    self.activated = false
  end

  private
  # Return a string with all weird character escaped
  # Words will be seperated by dashes and all special characters will be removed
  def escape_characters string
    link_string = String.new string
    characters = { ['á','à','â','ä','ã','Ã','Ä','Â','À'] => 'a',
       ['é','è','ê','ë','Ë','É','È','Ê'] => 'e',
       ['í','ì','î','ï','I','Î','Ì'] => 'i',
       ['ó','ò','ô','ö','õ','Õ','Ö','Ô','Ò'] => 'o',
       ['œ'] => 'oe',
       ['ú','ù','û','ü','U','Û','Ù'] => 'u',
       ['ç','Ç'] => 'c',
       [' '] => '-',
       ['.',',',';','?','!',':','=','+','=','<','>','%','^','$','€','&',')','(','…','\'','"', '/'] => '-'
       }

     characters.each do |char,rep|
       char.each do |s|
         link_string.gsub!(s, rep)
       end
     end
     link_string.gsub!(/-+/, '-')
     link_string.gsub!(/-$/,'')
     link_string.gsub!(/^-/,'')
     link_string.downcase
  end
end
