# Copyright (c) 2020 Crystal Data Contributors
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require "../array/array"
require "../libs/cblas"
require "../cltensor/cltensor"
require "../cltensor/storage"
require "../cltensor/global"
require "../num/math"

class Tensor(T) < AnyArray(T)
  def basetype(t : U.class) forall U
    Tensor(U)
  end

  def check_type
    {% unless T == Float32 || T == Float64 || T == Int16 || T == Int32 || \
                 T == Int8 || T == UInt16 || T == UInt32 || T == UInt64 || \
                 T == UInt8 || T == Bool || T == Complex %}
      {% raise "Bad dtype: #{T}. #{T} is not supported for Tensors" %}
    {% end %}
  end

  def opencl
    if @flags.contiguous?
      writer = self
    else
      writer = dup(Num::RowMajor)
    end
    gpu = NumInternal::ClStorage(T).new(@size)
    Cl.write(Num::ClContext.instance.queue, writer.to_unsafe, gpu.to_unsafe, UInt64.new(@size * sizeof(T)))
    ClTensor(T).new(gpu, @shape)
  end

  def **(other)
    Num.power(self, other)
  end

  def +(other)
    Num.add(self, other)
  end

  def -(other)
    Num.subtract(self, other)
  end

  def *(other)
    Num.multiply(self, other)
  end

  def /(other)
    Num.divide(self, other)
  end

  def //(other)
    Num.floordiv(self, other)
  end

  def <<(other)
    Num.left_shift(self, other)
  end

  def >>(other)
    Num.right_shift(self, other)
  end

  def &(other)
    Num.bitwise_and(self, other)
  end

  def |(other)
    Num.bitwise_or(self, other)
  end

  def ^(other)
    Num.bitwise_xor(self, other)
  end

  def ==(other)
    Num.equal(self, other)
  end

  def !=(other)
    Num.not_equal(self, other)
  end

  def <(other)
    Num.less(self, other)
  end

  def <=(other)
    Num.less_equal(self, other)
  end

  def >(other)
    Num.greater(self, other)
  end

  def >=(other)
    Num.greater_equal(self, other)
  end
end
