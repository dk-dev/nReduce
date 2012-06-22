require 'json/add/rails'

class Cache
  @@enabled = true

    # Set a cache value - can pass a block where you set the value
    # If cache key isn't a string, cache class will hash it
    # Unless raw is passed, it serializes to JSON
  def self.set(key, value, expires_in = nil, raw = false)
    return true if !@@enabled
    key = Cache.key_for(key) unless key.is_a?(String)
    value = JSON.generate(value) unless raw
    res = $redis.set(key, value) == 'OK' ? true : false
    $redis.expire(key, expires_in) if res and !expires_in.blank?
    res
  end

    # Get a cache key
    # Can pass a block that returns the value you'd like to set (like the results of a db query)
  def self.get(key, expires_in = nil, raw = false, &block)
    if !@@enabled
      # If cache is disabled return block
      if block.blank?
        return yield
      else
        return nil
      end
    end
    key = Cache.key_for(key) unless key.is_a?(String)
    value = $redis.get(key)
    # If key isn't set, and block is passed - set key to return value of block
    if !value.nil?
      value = JSON.parse(value) unless value.blank? or raw
    elsif value.nil? and !block.blank?
      value = yield
      Cache.set(key, value, expires_in, raw)
    end
    value
  end

    # Deletes a key
  def self.delete(key)
    key = Cache.key_for(key) unless key.is_a?(String)
    $redis.del(key) # returns 1 if was set, 0 if not. ignore results anyway
    true
  end

  # Hashes objects to a key that can be used for cache set/get
  def self.key_for(*args)
    # if args is an array of items, flatten it
    args = args.flatten if args.size == 1 and args.first.is_a?(Array)
    # any args that are active record objects - use classname_id
    args.map{|a| (a.respond_to?(:new_record?)) ? "#{a.class}_#{a.id}" : a.to_s }.join('_').downcase
  end

  def self.enabled?
    @@enabled
  end

  def self.enabled=(enabled)
    @@enabled = enabled
  end
end